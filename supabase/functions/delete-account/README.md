# delete-account

Edge function that permanently deletes the calling user's Supabase auth account
and, through foreign-key cascades, all of their application data. This is the
backend half of the "Danger Zone → Delete account" flow in the SubTrkr desktop
app (`src/components/AccountSettings.tsx`).

## Contract

| | |
| --- | --- |
| Method | `POST` (plus `OPTIONS` preflight). Anything else → `405`. |
| Auth | User JWT in `Authorization: Bearer <token>`, resolved in-function via `supabase.auth.getUser(token)` with a service-role client. |
| Body | Ignored. The user id comes from the token, never from the request — a caller can only delete *themselves*. |
| Success | `200 { "success": true }` |
| Failure | `401 { "success": false, "error": "No authorization header" \| "Invalid token" }`, `405`, or `500` with a fixed generic message. |

Failures never echo the underlying Postgres / GoTrue error to the client; the
detail is written to the function logs instead.

`verify_jwt` is left at its default (`true`) — no `[functions.delete-account]`
block in `supabase/config.toml` — so the platform rejects unsigned requests
before the function even runs. That is *not* sufficient on its own (the anon key
is itself a valid JWT and ships in every client binary), which is why the
function resolves a real user from the token as well.

## What gets deleted

`auth.admin.deleteUser(user.id)` performs a hard delete of the `auth.users`
row. Everything else goes away via `ON DELETE CASCADE`.

Verified in this repo's migrations
(`20260206035747_add_notification_system.sql`, and
`20260124_add_status_system.sql` in the desktop repo):

| Table | FK | Action |
| --- | --- | --- |
| `notification_channels` | `user_id → auth.users(id)` | `CASCADE` |
| `notification_preferences` | `user_id → auth.users(id)` | `CASCADE` |
| `notification_log` | `user_id → auth.users(id)` | `CASCADE` |
| `notification_log` | `item_id → items(id)` | `SET NULL` |
| `item_status_history` | `item_id → items(id)` | `CASCADE` |

⚠️ **Not verifiable from source.** `items`, `categories`, and `payments` were
created in the Supabase dashboard before this repo tracked migrations, so no
`CREATE TABLE` for them exists here. Their `user_id → auth.users(id)` FK actions
must be confirmed against the live database **before deploying**:

```sql
select
  c.conrelid::regclass as table_name,
  c.conname,
  pg_get_constraintdef(c.oid) as definition
from pg_constraint c
where c.contype = 'f'
  and c.conrelid::regclass::text in
      ('items', 'categories', 'payments', 'item_status_history',
       'notification_channels', 'notification_log', 'notification_preferences');
```

Two outcomes to watch for:

1. **A `user_id` FK with no `ON DELETE` action** (the default `NO ACTION`) makes
   `deleteUser` fail outright with a foreign-key violation — the user sees the
   generic 500 and nothing is deleted. Fix with a migration that re-creates the
   constraint as `ON DELETE CASCADE`.
2. **`items.category_id → categories(id)` without a cascade.** If both `items`
   and `categories` cascade from `auth.users`, Postgres may try to delete a
   `categories` row that surviving `items` rows still reference and abort the
   whole delete. `items.category_id` should be `ON DELETE SET NULL` (or
   `CASCADE`) for the account delete to be reliable.

If either FK needs changing, ship the migration **before** the function.

## Deployment

Deployment is a gated, manual step — it is deliberately not run by tooling.

```bash
supabase functions deploy delete-account --project-ref bpgsfyallqqvvtjorybl
```

No new function secrets are required: `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` are injected by the platform.

Until this is deployed, the desktop UI's delete button surfaces
"Account deletion is temporarily unavailable" and no data is touched.

## Manual smoke test

Use a throwaway account.

```bash
curl -i -X POST \
  "https://bpgsfyallqqvvtjorybl.supabase.co/functions/v1/delete-account" \
  -H "Authorization: Bearer <that account's access token>" \
  -H "apikey: <anon key>"
```

Expect `200 {"success":true}`, then confirm the `auth.users` row and the
account's `items` / `categories` / `notification_*` rows are all gone.
