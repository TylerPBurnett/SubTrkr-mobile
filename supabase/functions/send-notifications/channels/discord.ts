import { validateWebhookUrl } from "../utils/webhookValidator.ts";

export async function sendDiscord(
  webhookUrl: string,
  message: string,
): Promise<void> {
  const validation = validateWebhookUrl("discord", webhookUrl);
  if (!validation.ok) {
    throw new Error(`Refused to send Discord webhook: ${validation.error}`);
  }

  const resp = await fetch(validation.url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content: message }),
  });

  if (!resp.ok) {
    const body = await resp.text();
    throw new Error(`Discord webhook error ${resp.status}: ${body}`);
  }
}
