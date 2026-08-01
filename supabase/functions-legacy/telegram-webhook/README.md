# telegram-webhook (deleted 2026-08-01)

Telegram Bot API webhook receiver from the original central-bot design: users
messaged the shared SubTrkr bot with `/start <linking-code>` and the function
matched the code against `notification_channels.metadata->>linking_code`
(10-minute expiry) to store their `chat_id`. Deployed 2026-02-06 (v3), deleted
2026-08-01. `index.ts` here is the v3 artifact, downloaded from the live
deployment immediately before deletion.

## Why it was deleted

- **The linking flow it served no longer exists.** Telegram notifications moved
  to user-owned bots with auto-detected chat IDs the same week it shipped; the
  docs have marked it "Not needed (users own their bots)" since February.
  Nothing in the desktop or iOS repo references it (verified by grep on
  2026-08-01).
- **Its bot is gone.** `TELEGRAM_BOT_TOKEN` is no longer among the project's
  function secrets (checked 2026-08-01), so the deployed function could not
  even send its reply messages. If the retired central bot still has a webhook
  registered with Telegram, those deliveries now get a 404, which Telegram
  tolerates; clearing it would require the old bot token via
  `deleteWebhook`.

## Security posture as deployed

This was the riskier of the two legacy functions. The header comment claims
"we validate via the bot token in the URL path instead", but **the code
performs no request authentication of any kind** — no URL-path token check, no
`X-Telegram-Bot-Api-Secret-Token` comparison. With `verify_jwt = false`, anyone
could POST forged Telegram updates. An attacker who obtained or guessed an
active linking code within its 10-minute window could bind their own `chat_id`
to the victim's channel, silently rerouting every subscription reminder to
themselves. The update at line 113 also replaced the whole `metadata` object
rather than merging it. None of this was exploitable after the flow was
abandoned (no codes were being generated), but it is why unreviewed
`verify_jwt = false` functions get deleted rather than left idling.
