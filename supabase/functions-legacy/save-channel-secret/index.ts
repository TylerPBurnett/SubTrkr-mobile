import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const VALID_CHANNELS = ["telegram", "discord", "slack"] as const;
type ChannelType = (typeof VALID_CHANNELS)[number];

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function validateWebhookUrl(channel: ChannelType, url: string): boolean {
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== "https:") return false;

    switch (channel) {
      case "discord":
        return parsed.hostname === "discord.com" && parsed.pathname.startsWith("/api/webhooks/");
      case "slack":
        return parsed.hostname === "hooks.slack.com" && parsed.pathname.startsWith("/services/");
      default:
        return false;
    }
  } catch {
    return false;
  }
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { db: { schema: 'public' } }
    );

    // Authenticate user
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "No authorization header" }, 401);
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);

    if (authError || !user) {
      return jsonResponse({ error: "Invalid token", details: authError?.message }, 401);
    }

    // Parse and validate body
    const body = await req.json();
    const { channel, secret_value } = body as { channel: ChannelType; secret_value: string };

    if (!channel || !VALID_CHANNELS.includes(channel)) {
      return jsonResponse({ error: "Invalid channel" }, 400);
    }

    if (!secret_value || typeof secret_value !== "string" || secret_value.trim().length === 0) {
      return jsonResponse({ error: "Secret value is required" }, 400);
    }

    if ((channel === "discord" || channel === "slack") && !validateWebhookUrl(channel, secret_value)) {
      return jsonResponse({ error: `Invalid ${channel} webhook URL` }, 400);
    }

    const secretName = `notif_${user.id}_${channel}`;

    // Check for existing channel to clean up old secret
    const { data: existingChannel } = await supabaseAdmin
      .from("notification_channels")
      .select("vault_secret_id")
      .eq("user_id", user.id)
      .eq("channel", channel)
      .maybeSingle();

    if (existingChannel?.vault_secret_id) {
      // Delete old secret from vault via raw SQL
      await supabaseAdmin.rpc("delete_secret", {
        secret_id: existingChannel.vault_secret_id,
      });
    }

    // Use raw SQL to call vault.create_secret (public wrapper has pgsodium permission issues)
    const { data: vaultRows, error: vaultError } = await supabaseAdmin
      .from('_sqlx')
      .rpc('vault_create_secret_noop', {})
      .select();

    // Actually, use the Supabase REST API to run raw SQL via postgrest
    // Better approach: just insert directly and let the trigger handle encryption
    // Or call vault.create_secret via a simple SQL function

    // Direct approach: call vault.create_secret via raw SQL using supabase-js
    const vaultResult = await fetch(
      `${Deno.env.get("SUPABASE_URL")}/rest/v1/rpc/create_secret`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
          'Authorization': `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!}`,
          'Accept': 'application/json',
          'Content-Profile': 'vault',
        },
        body: JSON.stringify({
          new_secret: secret_value,
          new_name: secretName,
        }),
      }
    );

    if (!vaultResult.ok) {
      const errText = await vaultResult.text();
      return jsonResponse({ error: "Failed to store secret", details: errText }, 500);
    }

    const vaultSecretId = await vaultResult.json();

    // Upsert notification channel
    const { error: upsertError } = await supabaseAdmin
      .from("notification_channels")
      .upsert(
        {
          user_id: user.id,
          channel,
          vault_secret_id: vaultSecretId,
          enabled: true,
        },
        { onConflict: "user_id,channel" }
      );

    if (upsertError) {
      return jsonResponse({ error: "Failed to update channel config", details: upsertError.message }, 500);
    }

    return jsonResponse({ vault_secret_id: vaultSecretId });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Internal error";
    return jsonResponse({ error: msg }, 500);
  }
});
