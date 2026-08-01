import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { sendTelegram } from "./channels/telegram.ts";
import { sendDiscord } from "./channels/discord.ts";
import { sendSlack } from "./channels/slack.ts";
import { formatRenewalMessage, formatTrialMessage, formatTestMessage } from "./utils/templates.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-cron-secret',
};

const CONCURRENCY_LIMIT = 20; // Max concurrent API requests

interface DueItem {
  user_id: string;
  item_id: string;
  item_name: string;
  amount: number;
  currency: string;
  billing_cycle: string;
  next_billing_date: string;
  trial_end_date: string | null;
  item_status: string;
  reminder_days: number;
  event_type: "renewal_reminder" | "trial_expiration";
  user_timezone: string; // NEW: returned by DB function (for logging/debugging)
}

interface ChannelRow {
  id: string;
  user_id: string;
  channel: "telegram" | "discord" | "slack";
  enabled: boolean;
  secret_value: string | null;
  metadata: Record<string, unknown>;
  event_types: string[];
}

type ChannelType = "telegram" | "discord" | "slack";

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Simple concurrency limiter (replaces p-limit)
class ConcurrencyLimiter {
  private queue: Array<() => void> = [];
  private running = 0;

  constructor(private limit: number) {}

  async run<T>(fn: () => Promise<T>): Promise<T> {
    while (this.running >= this.limit) {
      await new Promise<void>(resolve => this.queue.push(resolve));
    }
    this.running++;
    try {
      return await fn();
    } finally {
      this.running--;
      const next = this.queue.shift();
      if (next) next();
    }
  }
}

async function dispatchToChannel(
  channel: ChannelType,
  secret: string,
  metadata: Record<string, unknown>,
  message: string
): Promise<void> {
  switch (channel) {
    case "telegram":
      await sendTelegram(secret, metadata.chat_id as string, message);
      break;
    case "discord":
      await sendDiscord(secret, message);
      break;
    case "slack":
      await sendSlack(secret, message);
      break;
  }
}

async function logNotification(
  supabase: ReturnType<typeof createClient>,
  entry: {
    user_id: string;
    channel: string;
    event_type: string;
    item_id: string | null;
    status: "sent" | "failed" | "skipped";
    error_message?: string;
  }
) {
  await supabase.from("notification_log").insert(entry);
}

// Constant-time comparison so the cron secret cannot be recovered by timing
// the 401 responses. Length is compared first and does leak, which is
// acceptable for a fixed-length generated secret.
function secretsMatch(provided: string, expected: string): boolean {
  const encoder = new TextEncoder();
  const a = encoder.encode(provided);
  const b = encoder.encode(expected);
  if (a.length !== b.length) return false;

  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff === 0;
}

type ClaimResult =
  | { ok: true; id: string }
  | { ok: false; reason: "duplicate" }
  | { ok: false; reason: "error"; error: string };

// Claim-then-send: insert a 'pending' row BEFORE dispatching. The partial
// unique index idx_notification_log_claim (user_id, item_id, channel,
// event_type, UTC day) WHERE status IN ('pending','sent') makes this the real
// deduplication boundary -- two concurrent invocations race on the insert and
// exactly one wins.
//
// PostgREST cannot target an expression index with on_conflict, so the loser is
// detected from the SQLSTATE of a plain insert: 23505 = unique_violation.
async function claimNotification(
  supabase: ReturnType<typeof createClient>,
  entry: {
    user_id: string;
    channel: string;
    event_type: string;
    item_id: string;
  }
): Promise<ClaimResult> {
  const { data, error } = await supabase
    .from("notification_log")
    .insert({ ...entry, status: "pending" })
    .select("id")
    .single();

  if (error) {
    if (error.code === "23505") return { ok: false, reason: "duplicate" };
    return { ok: false, reason: "error", error: error.message };
  }

  if (!data?.id) {
    return { ok: false, reason: "error", error: "Claim insert returned no row" };
  }

  return { ok: true, id: data.id as string };
}

// Resolve a claimed row after dispatch. 'failed' drops out of the partial
// index so the notification can be retried on a later run; 'sent' keeps
// holding the claim for the rest of the UTC day.
//
// sent_at is deliberately NOT refreshed here: it is part of the claim index
// key, and moving it across a UTC midnight boundary between claim and
// finalize would both release the day's claim and risk a second unique
// violation on the update. The claim timestamp is within seconds of the send.
async function finalizeNotification(
  supabase: ReturnType<typeof createClient>,
  id: string,
  status: "sent" | "failed",
  errorMessage?: string
) {
  const patch: Record<string, unknown> = { status };
  if (errorMessage !== undefined) patch.error_message = errorMessage;

  const { error } = await supabase
    .from("notification_log")
    .update(patch)
    .eq("id", id);

  if (error) {
    // Dispatch already happened (or already failed), so the only cost is a row
    // stuck at 'pending'. That is the safe direction: it keeps holding the
    // claim, which blocks a duplicate send for the rest of the UTC day.
    console.error(`Failed to finalize notification ${id} as '${status}': ${error.message}`);
  }
}

// OPTIMIZATION 2: Bulk deduplication check.
// Fast path only -- it skips work that the claim insert would reject anyway.
// 'pending' counts as claimed: an in-flight notification from a concurrent
// invocation must not be sent a second time.
async function getBulkClaimedToday(
  supabase: ReturnType<typeof createClient>,
  userIds: string[],
  todayStart: Date
): Promise<Set<string>> {
  if (userIds.length === 0) return new Set();

  const { data } = await supabase
    .from("notification_log")
    .select("user_id, item_id, channel, event_type")
    .in("user_id", userIds)
    .in("status", ["pending", "sent"])
    .gte("sent_at", todayStart.toISOString());

  return new Set(
    (data || []).map(s => `${s.user_id}:${s.item_id}:${s.channel}:${s.event_type}`)
  );
}

function makeDedupeKey(
  userId: string,
  itemId: string,
  channel: string,
  eventType: string
): string {
  return `${userId}:${itemId}:${channel}:${eventType}`;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const body = await req.json().catch(() => ({}));

    // === Test notification mode ===
    if (body.test && body.channel) {
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) {
        return jsonResponse({ success: false, error: "No authorization header" }, 401);
      }

      const token = authHeader.replace("Bearer ", "");
      const { data: { user }, error: authError } = await supabase.auth.getUser(token);

      if (authError || !user) {
        return jsonResponse({ success: false, error: "Invalid token" }, 401);
      }

      const { data: channelConfig } = await supabase
        .from("notification_channels")
        .select("*")
        .eq("user_id", user.id)
        .eq("channel", body.channel)
        .single();

      if (!channelConfig || !channelConfig.secret_value) {
        return jsonResponse({ success: false, error: `${body.channel} is not configured` }, 400);
      }

      try {
        const message = formatTestMessage(body.channel);
        await dispatchToChannel(body.channel, channelConfig.secret_value, channelConfig.metadata ?? {}, message);
        await logNotification(supabase, {
          user_id: user.id,
          channel: body.channel,
          event_type: "renewal_reminder",
          item_id: null,
          status: "sent",
        });
        return jsonResponse({ success: true });
      } catch (err) {
        const errorMsg = err instanceof Error ? err.message : "Unknown error";
        await logNotification(supabase, {
          user_id: user.id,
          channel: body.channel,
          event_type: "renewal_reminder",
          item_id: null,
          status: "failed",
          error_message: errorMsg,
        });
        return jsonResponse({ success: false, error: errorMsg }, 500);
      }
    }

    // === Scheduled notification mode ===
    // This function runs with verify_jwt = false (pg_cron calls it with the anon
    // key, which ships inside every client binary), so nothing above the platform
    // stops an arbitrary caller from triggering a full fleet-wide dispatch. A
    // shared secret header is the gate.
    //
    // Fails CLOSED on purpose: an unset CRON_SECRET disables scheduled dispatch
    // rather than leaving the endpoint open. Set it with
    // `supabase secrets set CRON_SECRET=...` -- see README.md.
    const cronSecret = Deno.env.get("CRON_SECRET");
    if (!cronSecret) {
      return jsonResponse(
        { error: "Scheduled dispatch is disabled: CRON_SECRET is not configured" },
        401
      );
    }

    const providedCronSecret = req.headers.get("x-cron-secret");
    if (!providedCronSecret || !secretsMatch(providedCronSecret, cronSecret)) {
      return jsonResponse(
        { error: "Missing or invalid x-cron-secret header" },
        401
      );
    }

    // Note: DB function now filters by timezone - only returns items where user's local time = 9 AM
    const { data: dueItems, error: queryError } = await supabase.rpc(
      "get_items_due_for_notification"
    );

    if (queryError) {
      return jsonResponse({ error: queryError.message }, 500);
    }

    if (!dueItems || dueItems.length === 0) {
      return jsonResponse({ processed: 0, message: "No items due for this hour" });
    }

    // Group items by user
    const itemsByUser = new Map<string, DueItem[]>();
    for (const item of dueItems as DueItem[]) {
      const existing = itemsByUser.get(item.user_id) ?? [];
      existing.push(item);
      itemsByUser.set(item.user_id, existing);
    }

    const userIds = Array.from(itemsByUser.keys());

    // OPTIMIZATION 3: Prefetch all channels in one query
    const { data: allChannels } = await supabase
      .from("notification_channels")
      .select("*")
      .in("user_id", userIds)
      .eq("enabled", true);

    if (!allChannels || allChannels.length === 0) {
      return jsonResponse({ processed: 0, message: "No enabled channels" });
    }

    // Group channels by user_id
    const channelsByUser = new Map<string, ChannelRow[]>();
    for (const ch of allChannels as ChannelRow[]) {
      const existing = channelsByUser.get(ch.user_id) ?? [];
      existing.push(ch);
      channelsByUser.set(ch.user_id, existing);
    }

    // OPTIMIZATION 2: Bulk deduplication - single query for everything already
    // claimed (pending) or delivered (sent) today. The authoritative check is
    // the claim insert inside each dispatch task; this only trims obvious work.
    const todayStart = new Date();
    todayStart.setUTCHours(0, 0, 0, 0);
    const claimedSet = await getBulkClaimedToday(supabase, userIds, todayStart);

    // Collect all dispatch tasks for parallel execution
    const dispatchTasks: Array<() => Promise<void>> = [];
    let totalSent = 0;
    let totalSkipped = 0;
    let totalFailed = 0;

    for (const [userId, items] of itemsByUser) {
      const channels = channelsByUser.get(userId) ?? [];
      if (channels.length === 0) continue;

      for (const channelConfig of channels) {
        if (!channelConfig.secret_value) continue;

        for (const item of items) {
          if (!channelConfig.event_types.includes(item.event_type)) {
            continue;
          }

          // Check deduplication using in-memory Set (O(1))
          const dedupeKey = makeDedupeKey(
            userId,
            item.item_id,
            channelConfig.channel,
            item.event_type
          );
          if (claimedSet.has(dedupeKey)) {
            totalSkipped++;
            continue;
          }

          // Create dispatch task (will run in parallel)
          dispatchTasks.push(async () => {
            // Claim before sending. Losing this race means another invocation
            // is already handling it, so nothing is dispatched here.
            const claim = await claimNotification(supabase, {
              user_id: userId,
              channel: channelConfig.channel,
              event_type: item.event_type,
              item_id: item.item_id,
            });

            if (!claim.ok) {
              if (claim.reason === "duplicate") {
                totalSkipped++;
              } else {
                // Fail safe: without a claim row the send would be unlogged and
                // could repeat on the next run, so it is not attempted at all.
                console.error(
                  `Failed to claim notification (user ${userId}, item ${item.item_id}, ${channelConfig.channel}): ${claim.error}`
                );
                totalFailed++;
              }
              return;
            }

            try {
              const message =
                item.event_type === "renewal_reminder"
                  ? formatRenewalMessage(item)
                  : formatTrialMessage(item);

              await dispatchToChannel(
                channelConfig.channel,
                channelConfig.secret_value!,
                channelConfig.metadata ?? {},
                message
              );

              await finalizeNotification(supabase, claim.id, "sent");
              totalSent++;
            } catch (err) {
              const errorMsg = err instanceof Error ? err.message : "Unknown error";
              await finalizeNotification(supabase, claim.id, "failed", errorMsg);
              totalFailed++;
            }
          });
        }
      }
    }

    // OPTIMIZATION 1: Parallel dispatch with concurrency limit
    const limiter = new ConcurrencyLimiter(CONCURRENCY_LIMIT);
    await Promise.all(dispatchTasks.map(task => limiter.run(task)));

    return jsonResponse({
      processed: totalSent + totalSkipped + totalFailed,
      sent: totalSent,
      skipped: totalSkipped,
      failed: totalFailed,
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Internal error";
    return jsonResponse({ error: msg }, 500);
  }
});
