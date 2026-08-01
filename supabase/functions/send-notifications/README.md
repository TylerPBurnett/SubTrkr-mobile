# send-notifications

Edge function that delivers SubTrkr renewal and trial reminders to a user's
configured Telegram / Discord / Slack channels.

It has two modes, distinguished by the request body:

| Mode | Trigger | Authentication |
| --- | --- | --- |
| Test | `{ "test": true, "channel": "telegram" }` | User JWT in `Authorization: Bearer <token>`, verified in-function via `supabase.auth.getUser()` |
| Scheduled | anything else (pg_cron sends `{ "scheduled": true, ... }`) | Shared secret in `x-cron-secret`, compared against the `CRON_SECRET` function secret |

## Why the scheduled mode needs its own secret

`supabase/config.toml` sets `verify_jwt = false` for this function, because
pg_cron invokes it with the anon key and platform-level JWT verification would
reject that. The anon key also ships inside every desktop and mobile binary, so
it is not a secret in any meaningful sense.

Without a gate, *anyone* who knows the function URL can trigger a full
fleet-wide dispatch: every user's reminders sent at once, at an arbitrary hour,
burning through Telegram/Discord/Slack rate limits and the notification budget.

The gate **fails closed**. If `CRON_SECRET` is unset, or the `x-cron-secret`
header is missing or does not match, the scheduled path returns `401` and does
nothing. Test mode is unaffected — it still authenticates with a real user JWT.

> An unset `CRON_SECRET` means **no notifications go out at all**. Set the secret
> before (or at the same time as) deploying this version.

## Deployment

> **Apply the migrations before deploying this function.** This version writes
> `notification_log.status = 'pending'`, which the original CHECK constraint
> (`sent`/`failed`/`skipped`) rejects. Deployed against the old schema, every
> claim insert fails and **no notifications are sent at all**.
> `supabase/migrations/20260801090300_notification_log_claim_dedup.sql` widens
> the constraint and creates the claim index. The reverse order — migration
> first, function later — is safe: the old function never writes `'pending'`.

Run these in order. Steps 1–4 are safe to perform while the currently deployed
version is still running: the old code ignores the extra header, so there is no
window where scheduled notifications stop.

### 1. Generate a secret

At least 32 bytes of randomness:

```bash
openssl rand -base64 32
```

Copy the output. It is used verbatim in steps 2 and 3 — they must match exactly,
including any trailing `=` padding.

### 2. Store it as a function secret

```bash
supabase secrets set CRON_SECRET='<value from step 1>'
```

Quote the value — base64 output can contain `+` and `/`. This is what
`Deno.env.get("CRON_SECRET")` reads at runtime. Verify with:

```bash
supabase secrets list
```

(The listing shows a digest, not the value.)

### 3. Store the same value in Vault

pg_cron cannot read edge function secrets, so it needs its own copy. In the
Supabase dashboard **SQL Editor**:

```sql
SELECT vault.create_secret(
  '<value from step 1>',
  'cron_secret',
  'Shared secret for the send-notifications scheduled dispatch gate'
);
```

This sits alongside the existing `project_url` and `anon_key` Vault secrets that
the cron job already reads.

To rotate later, replace rather than re-create:

```sql
SELECT vault.update_secret(
  (SELECT id FROM vault.secrets WHERE name = 'cron_secret'),
  '<new value>'
);
```

### 4. Update the cron schedule

Cron changes **cannot ship in a migration** — the migration role lacks the
permissions for `cron.schedule` / `cron.unschedule`. Run this in the dashboard
**SQL Editor**.

It is the SQL from the comment at the bottom of
`supabase/migrations/20260208195618_add_timezone_aware_notifications.sql`, plus
the `x-cron-secret` header sourced from Vault:

```sql
SELECT cron.unschedule('hourly-notification-check');

SELECT cron.schedule(
  'hourly-notification-check',
  '0 * * * *',
  $$
  SELECT net.http_post(
    url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
           || '/functions/v1/send-notifications',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'anon_key'),
      'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cron_secret')
    ),
    body := jsonb_build_object('scheduled', true, 'time', now()),
    timeout_milliseconds := 30000
  ) AS request_id;
  $$
);
```

Confirm the job is registered and the command contains the header:

```sql
SELECT jobname, schedule, active FROM cron.job WHERE jobname = 'hourly-notification-check';
```

### 5. Deploy the function

Migrations first (see the warning at the top of this section), then the function:

```bash
supabase db push          # must include 20260801090300_notification_log_claim_dedup.sql
supabase functions deploy send-notifications
```

### 6. Verify

An unauthenticated scheduled request must be rejected:

```bash
curl -i -X POST 'https://<project-ref>.supabase.co/functions/v1/send-notifications' \
  -H 'Content-Type: application/json' \
  -d '{"scheduled": true}'
# expect: HTTP/1.1 401  {"error":"Missing or invalid x-cron-secret header"}
```

Then check that the real job succeeds on the next hour boundary:

```sql
SELECT status, return_message, start_time
FROM cron.job_run_details
WHERE jobname = 'hourly-notification-check'
ORDER BY start_time DESC
LIMIT 5;
```

`net.http_post` is asynchronous, so a successful cron run only means the request
was queued. For the function's own response, check the edge function logs in the
dashboard, or:

```sql
SELECT status_code, content
FROM net._http_response
ORDER BY created DESC
LIMIT 5;
```

A `401` with `"CRON_SECRET is not configured"` means step 2 did not take effect;
a `401` with `"Missing or invalid x-cron-secret header"` means step 3 or 4 is
wrong or out of sync with step 2.

**Never put `CRON_SECRET` in client configuration.** It belongs only in Supabase
function secrets and Vault. Anything shipped in a desktop or mobile binary is
public.

## Delivery deduplication (claim-then-send)

Duplicate reminders used to be possible: the function read today's log, decided
what to send, sent it, and only then wrote the log row. Two overlapping
invocations (a cron retry, a manual trigger) could both pass the read and both
send.

Dispatch now claims before sending:

1. Insert a `notification_log` row with `status = 'pending'` and read back its id.
2. If that insert fails with SQLSTATE `23505`, another invocation already claimed
   this notification — count it as skipped, send nothing.
3. Send, then update the claimed row to `'sent'`, or to `'failed'` with the error
   message.

The guarantee comes from `idx_notification_log_claim` (migration
`20260801090300_notification_log_claim_dedup.sql`): a partial unique index on
`(user_id, item_id, channel, event_type, (sent_at AT TIME ZONE 'UTC')::date)`
`WHERE status IN ('pending','sent') AND item_id IS NOT NULL`.

Consequences worth knowing:

- `'failed'` rows fall out of the index, so a failed notification is retried on
  the next run that same day.
- Test notifications have `item_id IS NULL` and are excluded from the index, so
  they stay repeatable.
- `sent_at` is set at claim time and is **not** refreshed on completion — it is
  part of the index key, and moving it across UTC midnight between claim and
  finalize would release the claim.
- The bulk prefetch at the start of a run is now only a fast path that avoids
  doomed inserts. The index is the actual boundary.

A row left at `'pending'` means the process died between sending and recording
the result. It holds its claim for the rest of the UTC day, which errs toward
not double-sending. To find them:

```sql
SELECT id, user_id, item_id, channel, event_type, sent_at
FROM public.notification_log
WHERE status = 'pending'
  AND sent_at < now() - interval '1 hour'
ORDER BY sent_at DESC;
```

## Local development

```bash
supabase functions serve send-notifications --env-file supabase/functions/.env.local
```

with an `.env.local` containing at least `CRON_SECRET=<any value>`, then:

```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/send-notifications' \
  -H 'Content-Type: application/json' \
  -H 'x-cron-secret: <same value>' \
  -d '{"scheduled": true}'
```

Do not commit `.env.local`.
