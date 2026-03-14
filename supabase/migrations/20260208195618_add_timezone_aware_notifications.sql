-- =====================================================
-- Migration: Add timezone-aware notifications (9 AM local time)
-- =====================================================

-- 1. Drop existing function (required when changing return type)
DROP FUNCTION IF EXISTS public.get_items_due_for_notification();

-- 2. Recreate function with timezone awareness
-- Only returns items for users where local time is currently 9 AM (9:00-9:59)
CREATE FUNCTION public.get_items_due_for_notification()
RETURNS TABLE(
  user_id uuid,
  item_id text,
  item_name text,
  amount numeric,
  currency text,
  billing_cycle text,
  next_billing_date date,
  trial_end_date date,
  item_status text,
  reminder_days integer,
  event_type notification_event_type,
  user_timezone text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  -- Renewal reminders for active items
  SELECT
    i.user_id,
    i.id,
    i.name,
    i.amount,
    i.currency,
    i.billing_cycle::text,
    i.next_billing_date::date,
    i.trial_end_date::date,
    i.status::text,
    COALESCE(i.reminder_days, np.default_reminder_days),
    'renewal_reminder'::public.notification_event_type,
    np.timezone
  FROM public.items i
  INNER JOIN public.notification_preferences np ON i.user_id = np.user_id
  WHERE i.status = 'active'
    AND i.next_billing_date IS NOT NULL
    AND COALESCE(i.reminder_days, np.default_reminder_days) > 0
    -- Date filtering: item is due within reminder window
    AND i.next_billing_date::date <= (CURRENT_DATE + COALESCE(i.reminder_days, np.default_reminder_days))
    AND i.next_billing_date::date >= CURRENT_DATE
    -- Timezone filtering: only return if user's local time is 9 AM hour
    AND EXTRACT(HOUR FROM (CURRENT_TIMESTAMP AT TIME ZONE np.timezone)) = 9

  UNION ALL

  -- Trial expiration reminders
  SELECT
    i.user_id,
    i.id,
    i.name,
    i.amount,
    i.currency,
    i.billing_cycle::text,
    i.next_billing_date::date,
    i.trial_end_date::date,
    i.status::text,
    COALESCE(i.reminder_days, np.default_reminder_days, 3),
    'trial_expiration'::public.notification_event_type,
    np.timezone
  FROM public.items i
  INNER JOIN public.notification_preferences np ON i.user_id = np.user_id
  WHERE i.status = 'trial'
    AND i.trial_end_date IS NOT NULL
    AND COALESCE(i.reminder_days, np.default_reminder_days, 3) > 0
    -- Date filtering: trial ending within reminder window
    AND i.trial_end_date::date <= (CURRENT_DATE + COALESCE(i.reminder_days, np.default_reminder_days, 3))
    AND i.trial_end_date::date >= CURRENT_DATE
    -- Timezone filtering: only return if user's local time is 9 AM hour
    AND EXTRACT(HOUR FROM (CURRENT_TIMESTAMP AT TIME ZONE np.timezone)) = 9;
END;
$$;

COMMENT ON FUNCTION public.get_items_due_for_notification() IS 
'Returns items due for notification, filtered by user timezone. Only returns items where user''s local time is 9 AM (9:00-9:59). Joins with notification_preferences to get timezone and default_reminder_days.';

-- Note: Cron schedule update must be done separately via Supabase SQL Editor
-- due to permission restrictions in migrations.
-- Run this after migration completes:
-- 
-- SELECT cron.unschedule('daily-notification-check');
-- SELECT cron.schedule(
--   'hourly-notification-check',
--   '0 * * * *',
--   $$
--   SELECT net.http_post(
--     url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
--            || '/functions/v1/send-notifications',
--     headers := jsonb_build_object(
--       'Content-Type', 'application/json',
--       'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'anon_key')
--     ),
--     body := jsonb_build_object('scheduled', true, 'time', now()),
--     timeout_milliseconds := 30000
--   ) AS request_id;
--   $$
-- );
;
