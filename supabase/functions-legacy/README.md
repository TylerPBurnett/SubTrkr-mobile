# functions-legacy

Source archive of edge functions that were **deleted from the Supabase project**
(`bpgsfyallqqvvtjorybl`). Kept for the record only.

**Do not deploy anything in this folder.** It sits outside `supabase/functions/`
precisely so `supabase functions deploy` can never pick these up. Both functions
target schema/RPCs that no longer exist and predate the Aug 2026 security
hardening.

| Function | Last deployed | Deleted | Why |
| --- | --- | --- | --- |
| `save-channel-secret` | v7, 2026-02-07 | 2026-08-01 | Superseded by direct writes to `notification_channels.secret_value`; depended on Vault helper RPCs removed by migration `20260801090100_remove_vault_helper_functions.sql`. Deployed version was also non-functional (see its README). |
| `telegram-webhook` | v3, 2026-02-06 | 2026-08-01 | Central-bot linking flow replaced by user-owned bots with auto-detected chat IDs. Accepted unauthenticated requests (see its README). |

Source was retrieved from the live deployment on 2026-08-01 via
`supabase functions download <name> --project-ref bpgsfyallqqvvtjorybl` before
deletion, so these files are byte-for-byte the last deployed artifacts.
