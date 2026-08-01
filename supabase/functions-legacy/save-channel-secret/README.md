# save-channel-secret (deleted 2026-08-01)

Proxy for writing notification channel secrets (Telegram bot tokens, Discord and
Slack webhook URLs) into Supabase Vault, storing the resulting
`vault_secret_id` on `notification_channels`. Deployed 2026-02-06, last updated
to v7 on 2026-02-07, deleted 2026-08-01. `index.ts` here is the v7 artifact,
downloaded from the live deployment immediately before deletion.

## Why it was deleted

- **Superseded the day after its last deploy.** Migration
  `20260207035015_add_secret_value_to_notification_channels.sql` moved secret
  storage to a plain `secret_value` column protected by RLS; the desktop app
  has written there directly ever since. Nothing in the desktop or iOS repo
  references this function (verified by grep on 2026-08-01).
- **Its dependencies were removed.** The Aug 2026 hardening dropped the public
  Vault helper RPCs (`20260801090100_remove_vault_helper_functions.sql`) that
  this function called (`delete_secret`, and `create_secret` via the `vault`
  PostgREST profile).
- **The deployed v7 could never succeed anyway.** Lines 96–99 call
  `.rpc('vault_create_secret_noop')` on a `PostgrestQueryBuilder`
  (`.from('_sqlx')`), which has no `.rpc` method. Every request that reached
  that point threw a `TypeError`, was caught by the outer handler, and returned
  a 500. The surrounding comments show v7 was abandoned mid-debug — the Vault
  approach was dropped in favor of the `secret_value` column instead of fixing
  it.

## Security posture as deployed

Deployed with `verify_jwt = false`, which is why it was flagged as a standing
risk. In fairness, the handler did its own authentication — it required an
`Authorization: Bearer` token and validated it with `auth.getUser()` before
doing anything — so it was not an open write endpoint. The real risks were
unreviewed drift: an always-500 function holding service-role credentials,
callable by any authenticated user, doing nothing anyone depended on.
