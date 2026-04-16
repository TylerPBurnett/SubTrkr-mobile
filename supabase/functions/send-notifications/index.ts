import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { sendTelegram } from "./channels/telegram.ts";
import { sendDiscord } from "./channels/discord.ts";
import { sendSlack } from "./channels/slack.ts";
import { formatRenewalMessage, formatTrialMessage, formatTestMessage } from "./utils/templates.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

// OPTIMIZATION 2: Bulk deduplication check
async function getBulkSentToday(
  supabase: ReturnType<typeof createClient>,
  userIds: string[],
  todayStart: Date
): Promise<Set<string>> {
  if (userIds.length === 0) return new Set();

  const { data } = await supabase
    .from("notification_log")
    .select("user_id, item_id, channel, event_type")
    .in("user_id", userIds)
    .eq("status", "sent")
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

    // OPTIMIZATION 2: Bulk deduplication - single query for all sent notifications today
    const todayStart = new Date();
    todayStart.setUTCHours(0, 0, 0, 0);
    const sentSet = await getBulkSentToday(supabase, userIds, todayStart);

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
          if (sentSet.has(dedupeKey)) {
            totalSkipped++;
            continue;
          }

          // Create dispatch task (will run in parallel)
          dispatchTasks.push(async () => {
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

              await logNotification(supabase, {
                user_id: userId,
                channel: channelConfig.channel,
                event_type: item.event_type,
                item_id: item.item_id,
                status: "sent",
              });
              totalSent++;
            } catch (err) {
              const errorMsg = err instanceof Error ? err.message : "Unknown error";
              await logNotification(supabase, {
                user_id: userId,
                channel: channelConfig.channel,
                event_type: item.event_type,
                item_id: item.item_id,
                status: "failed",
                error_message: errorMsg,
              });
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
