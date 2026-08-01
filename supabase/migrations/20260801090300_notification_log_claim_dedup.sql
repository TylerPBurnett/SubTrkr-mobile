-- =====================================================
-- Reliability Fix: database-level claim/dedup backstop for notification_log
-- =====================================================
--
-- Problem:
--   send-notifications dedupes in application memory: it reads today's 'sent'
--   rows (getBulkSentToday), decides what to send, then writes the log row after
--   dispatch. That read-then-write window means two concurrent invocations (a
--   pg_cron retry overlapping the hourly run, or a manual trigger) both see "not
--   sent yet" and both send -- the user gets duplicate reminders.
--
-- Direction:
--   Move to claim-then-send: the dispatcher INSERTs a 'pending' row FIRST and
--   only sends if that insert wins, then updates the row to 'sent' or 'failed'.
--   This migration provides the database half of that contract; the edge
--   function change lands separately.
--
-- 1. Allow the 'pending' status.
--    The original constraint was declared inline in
--    20260206035747_add_notification_system.sql as
--      status TEXT NOT NULL CHECK (status IN ('sent', 'failed', 'skipped'))
--    Inline CHECKs get an auto-generated name, and the deployed database may not
--    have landed on `notification_log_status_check` (Postgres appends _1, _2,
--    ... on collision). So find the status CHECK constraint(s) by inspecting
--    pg_constraint rather than guessing the name, drop them, and re-add under a
--    known name. Matching on conkey (the referenced column list) rather than the
--    constraint text avoids clobbering unrelated CHECKs.

DO $$
DECLARE
  v_constraint_name text;
BEGIN
  FOR v_constraint_name IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    WHERE nsp.nspname = 'public'
      AND rel.relname = 'notification_log'
      AND con.contype = 'c'
      AND EXISTS (
        SELECT 1
        FROM pg_attribute att
        WHERE att.attrelid = rel.oid
          AND att.attname = 'status'
          AND att.attnum = ANY (con.conkey)
      )
  LOOP
    EXECUTE format(
      'ALTER TABLE public.notification_log DROP CONSTRAINT %I',
      v_constraint_name
    );
  END LOOP;
END;
$$;

ALTER TABLE public.notification_log
  ADD CONSTRAINT notification_log_status_check
  CHECK (status IN ('pending', 'sent', 'failed', 'skipped'));

-- 2. The claim index: one in-flight-or-delivered notification per
--    (user, item, channel, event type) per UTC day. A second concurrent
--    dispatcher's claim INSERT fails on this unique index instead of
--    double-sending.
--
--    Note the expression: (sent_at AT TIME ZONE 'UTC')::date, NOT sent_at::date.
--    Casting timestamptz straight to date is only STABLE -- the result depends on
--    the session TimeZone setting -- so Postgres rejects it in an index
--    ("functions in index expression must be marked IMMUTABLE"). The two-argument
--    timezone(text, timestamptz) form pins the zone and is IMMUTABLE.
--
--    'failed' and 'skipped' rows are excluded so a failed attempt can be retried.
--    item_id IS NOT NULL excludes test notifications, which carry a null item_id
--    and must stay repeatable.

CREATE UNIQUE INDEX IF NOT EXISTS idx_notification_log_claim
  ON public.notification_log (
    user_id,
    item_id,
    channel,
    event_type,
    ((sent_at AT TIME ZONE 'UTC')::date)
  )
  WHERE status IN ('pending', 'sent') AND item_id IS NOT NULL;
