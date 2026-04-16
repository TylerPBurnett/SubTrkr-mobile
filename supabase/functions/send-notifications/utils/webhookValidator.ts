// Server-side mirror of the SubTrkr desktop client's webhook allowlist.
// MUST stay in sync with src/services/webhookValidator.ts in the SubTrkr repo.
//
// Goals (in order):
//   1. Strict allowlist per channel — only the canonical Discord/Slack
//      hostname + path prefix is accepted.
//   2. HTTPS only.
//   3. No embedded credentials (https://user:pass@host/...).
//   4. Defense in depth: explicit deny-list of loopback, RFC1918, link-local,
//      CGNAT, IPv6 ULA, and known cloud metadata hosts. The allowlist already
//      blocks these by hostname comparison, but the deny-list catches the case
//      where the allowlist is later loosened or bypassed.

const WEBHOOK_ALLOWLIST = {
  discord: { hostname: "discord.com", pathPrefix: "/api/webhooks/" },
  slack: { hostname: "hooks.slack.com", pathPrefix: "/services/" },
} as const;

export type AllowlistedChannel = keyof typeof WEBHOOK_ALLOWLIST;

const BLOCKED_HOST_PATTERNS: RegExp[] = [
  /^localhost$/i,
  /^127\./,                                       // loopback
  /^10\./,                                        // RFC1918
  /^192\.168\./,                                  // RFC1918
  /^172\.(1[6-9]|2\d|3[01])\./,                   // RFC1918
  /^169\.254\./,                                  // link-local (AWS/GCP/Azure IMDS)
  /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\./,    // CGNAT
  /^0\./,                                         // "this network"
  /^::1$/,                                        // IPv6 loopback
  /^fc/i,                                         // IPv6 ULA
  /^fd/i,                                         // IPv6 ULA
  /metadata\.google\.internal$/i,                 // GCP metadata
];

export type WebhookValidationResult =
  | { ok: true; url: string }
  | { ok: false; error: string };

export function validateWebhookUrl(
  channel: AllowlistedChannel,
  rawUrl: string,
): WebhookValidationResult {
  const trimmed = rawUrl.trim();
  if (!trimmed) return { ok: false, error: "Webhook URL is required." };

  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return { ok: false, error: "Webhook URL is not a valid URL." };
  }

  if (parsed.protocol !== "https:") {
    return { ok: false, error: "Webhook URL must use HTTPS." };
  }

  if (parsed.username || parsed.password) {
    return {
      ok: false,
      error: "Webhook URL must not contain embedded credentials.",
    };
  }

  const hostname = parsed.hostname.toLowerCase();

  for (const pattern of BLOCKED_HOST_PATTERNS) {
    if (pattern.test(hostname)) {
      return { ok: false, error: "Webhook URL points to a blocked host." };
    }
  }

  const expected = WEBHOOK_ALLOWLIST[channel];
  if (hostname !== expected.hostname) {
    const label = channel === "discord" ? "Discord" : "Slack";
    return {
      ok: false,
      error: `${label} webhook must be at https://${expected.hostname}/...`,
    };
  }

  if (!parsed.pathname.startsWith(expected.pathPrefix)) {
    return {
      ok: false,
      error: `Webhook URL must start with https://${expected.hostname}${expected.pathPrefix}...`,
    };
  }

  parsed.hash = ""; // never sent in POST; strip for clean storage/logging
  return { ok: true, url: parsed.toString() };
}
