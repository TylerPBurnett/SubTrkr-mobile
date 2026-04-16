import { validateWebhookUrl } from "../utils/webhookValidator.ts";

export async function sendSlack(
  webhookUrl: string,
  message: string,
): Promise<void> {
  const validation = validateWebhookUrl("slack", webhookUrl);
  if (!validation.ok) {
    throw new Error(`Refused to send Slack webhook: ${validation.error}`);
  }

  const resp = await fetch(validation.url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text: message }),
  });

  if (!resp.ok) {
    const body = await resp.text();
    throw new Error(`Slack webhook error ${resp.status}: ${body}`);
  }
}
