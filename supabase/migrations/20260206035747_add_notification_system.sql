
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- Notification channel enum
CREATE TYPE public.notification_channel AS ENUM ('telegram', 'discord', 'slack');

-- Notification event type enum
CREATE TYPE public.notification_event_type AS ENUM ('renewal_reminder', 'trial_expiration');

-- ============ notification_channels ============
CREATE TABLE public.notification_channels (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel public.notification_channel NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  vault_secret_id UUID,
  metadata JSONB DEFAULT '{}'::jsonb,
  event_types public.notification_event_type[] NOT NULL DEFAULT '{renewal_reminder, trial_expiration}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, channel)
);

ALTER TABLE public.notification_channels ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own notification channels"
  ON public.notification_channels FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_notification_channels_user ON public.notification_channels(user_id);

-- Trigger for updated_at
CREATE TRIGGER set_notification_channels_updated_at
  BEFORE UPDATE ON public.notification_channels
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============ notification_preferences ============
CREATE TABLE public.notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  default_reminder_days INTEGER NOT NULL DEFAULT 3,
  timezone TEXT NOT NULL DEFAULT 'UTC',
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own notification preferences"
  ON public.notification_preferences FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Trigger for updated_at
CREATE TRIGGER set_notification_preferences_updated_at
  BEFORE UPDATE ON public.notification_preferences
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============ notification_log ============
CREATE TABLE public.notification_log (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel public.notification_channel NOT NULL,
  event_type public.notification_event_type NOT NULL,
  item_id TEXT REFERENCES public.items(id) ON DELETE SET NULL,
  status TEXT NOT NULL CHECK (status IN ('sent', 'failed', 'skipped')),
  error_message TEXT,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.notification_log ENABLE ROW LEVEL SECURITY;

-- Users can only view their own logs
CREATE POLICY "Users view own notification logs"
  ON public.notification_log FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

CREATE INDEX idx_notification_log_user_date ON public.notification_log(user_id, sent_at DESC);
CREATE INDEX idx_notification_log_dedup ON public.notification_log(user_id, item_id, channel, event_type, sent_at);

-- ============ Server-side query function ============
CREATE OR REPLACE FUNCTION public.get_items_due_for_notification()
RETURNS TABLE (
  user_id UUID,
  item_id TEXT,
  item_name TEXT,
  amount NUMERIC,
  currency TEXT,
  billing_cycle TEXT,
  next_billing_date DATE,
  trial_end_date DATE,
  item_status TEXT,
  reminder_days INTEGER,
  event_type public.notification_event_type
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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
    i.reminder_days,
    'renewal_reminder'::public.notification_event_type
  FROM public.items i
  WHERE i.status = 'active'
    AND i.reminder_days > 0
    AND i.next_billing_date IS NOT NULL
    AND i.next_billing_date::date <= (CURRENT_DATE + i.reminder_days)
    AND i.next_billing_date::date >= CURRENT_DATE

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
    COALESCE(i.reminder_days, 3),
    'trial_expiration'::public.notification_event_type
  FROM public.items i
  WHERE i.status = 'trial'
    AND i.trial_end_date IS NOT NULL
    AND i.trial_end_date::date <= (CURRENT_DATE + COALESCE(i.reminder_days, 3))
    AND i.trial_end_date::date >= CURRENT_DATE;
END;
$$;
;
