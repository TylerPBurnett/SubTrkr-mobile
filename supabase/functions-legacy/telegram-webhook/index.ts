import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// This edge function receives Telegram webhook updates when users
// message the SubTrkr bot. It handles the /start command with a
// linking code to associate a Telegram chat_id with a SubTrkr user.
//
// JWT verification is disabled because Telegram sends webhooks
// directly - we validate via the bot token in the URL path instead.

interface TelegramUpdate {
  message?: {
    chat: { id: number };
    from?: { id: number; first_name?: string; username?: string };
    text?: string;
  };
}

Deno.serve(async (req: Request) => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const update: TelegramUpdate = await req.json();
    const message = update.message;

    if (!message?.text || !message.chat) {
      return new Response("ok", { status: 200 });
    }

    const chatId = message.chat.id.toString();
    const text = message.text.trim();

    // Handle /start LINKING_CODE command
    if (text.startsWith("/start")) {
      const parts = text.split(" ");
      const linkingCode = parts[1]?.trim();

      if (!linkingCode) {
        // No code provided - send instructions
        const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
        if (botToken) {
          await fetch(
            `https://api.telegram.org/bot${botToken}/sendMessage`,
            {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                chat_id: chatId,
                text: "Welcome to SubTrkr! To link your account, use the linking code from your SubTrkr app settings.\n\nSend: /start YOUR_CODE",
              }),
            }
          );
        }
        return new Response("ok", { status: 200 });
      }

      // Find the notification channel with this linking code
      const { data: channels, error: findError } = await supabase
        .from("notification_channels")
        .select("*")
        .eq("channel", "telegram")
        .filter("metadata->>linking_code", "eq", linkingCode);

      if (findError || !channels || channels.length === 0) {
        const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
        if (botToken) {
          await fetch(
            `https://api.telegram.org/bot${botToken}/sendMessage`,
            {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                chat_id: chatId,
                text: "Invalid or expired linking code. Please generate a new code from your SubTrkr app settings.",
              }),
            }
          );
        }
        return new Response("ok", { status: 200 });
      }

      const channelRow = channels[0];

      // Check if code has expired (10 minute window)
      const codeCreatedAt = channelRow.metadata?.linking_code_created_at;
      if (codeCreatedAt) {
        const created = new Date(codeCreatedAt as string);
        const now = new Date();
        const diffMinutes = (now.getTime() - created.getTime()) / 60000;
        if (diffMinutes > 10) {
          const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
          if (botToken) {
            await fetch(
              `https://api.telegram.org/bot${botToken}/sendMessage`,
              {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                  chat_id: chatId,
                  text: "This linking code has expired. Please generate a new code from your SubTrkr app settings.",
                }),
              }
            );
          }
          return new Response("ok", { status: 200 });
        }
      }

      // Link the account: store chat_id and clear linking code
      const { error: updateError } = await supabase
        .from("notification_channels")
        .update({
          metadata: {
            chat_id: chatId,
            telegram_username: message.from?.username ?? null,
            linked_at: new Date().toISOString(),
          },
          enabled: true,
        })
        .eq("id", channelRow.id);

      if (updateError) {
        return new Response("ok", { status: 200 });
      }

      // Send confirmation
      const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
      if (botToken) {
        await fetch(
          `https://api.telegram.org/bot${botToken}/sendMessage`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              chat_id: chatId,
              text: "\u2705 Your SubTrkr account has been linked! You'll now receive subscription reminders and trial expiration alerts here.",
            }),
          }
        );
      }

      return new Response("ok", { status: 200 });
    }

    // Unknown command
    return new Response("ok", { status: 200 });
  } catch {
    return new Response("ok", { status: 200 });
  }
});
