DROP FUNCTION IF EXISTS public.execute_item_status_change(
  text,
  text,
  date,
  date,
  date,
  date,
  text[],
  text,
  text,
  date,
  date
);

CREATE FUNCTION public.execute_item_status_change(
  p_item_id text,
  p_action text,
  p_effective_date date DEFAULT NULL,
  p_pause_until date DEFAULT NULL,
  p_trial_end_date date DEFAULT NULL,
  p_next_billing_date date DEFAULT NULL,
  p_clear_fields text[] DEFAULT ARRAY[]::text[],
  p_reason text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_today date DEFAULT NULL,
  p_minimum_effective_date date DEFAULT NULL
)
RETURNS public.items
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_item public.items%ROWTYPE;
  v_updated public.items%ROWTYPE;
  v_new_status public.item_status;
  v_authoritative_cancellation_history_id uuid;
  v_resolved_effective_date date := COALESCE(p_effective_date, p_today);
  v_trimmed_reason text := NULLIF(BTRIM(p_reason), '');
  v_trimmed_notes text := NULLIF(BTRIM(p_notes), '');
  v_history_notes text;
  v_clear_fields text[] := ARRAY[]::text[];
  v_effective_date_floor date;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING MESSAGE = 'Not authenticated';
  END IF;

  IF p_today IS NOT NULL AND ABS(p_today - CURRENT_DATE) > 1 THEN
    RAISE EXCEPTION USING MESSAGE = 'Today must reflect the caller''s current local date.';
  END IF;

  SELECT *
  INTO v_item
  FROM public.items
  WHERE id = p_item_id
    AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING MESSAGE = 'Item not found';
  END IF;

  v_new_status := CASE
    WHEN v_item.status = 'active' AND p_action = 'pause' THEN 'paused'::public.item_status
    WHEN v_item.status = 'active' AND p_action = 'cancel' THEN 'cancelled'::public.item_status
    WHEN v_item.status = 'active' AND p_action = 'start_trial' THEN 'trial'::public.item_status
    WHEN v_item.status = 'paused' AND p_action = 'resume' THEN 'active'::public.item_status
    WHEN v_item.status = 'paused' AND p_action = 'cancel' THEN 'cancelled'::public.item_status
    WHEN v_item.status = 'cancelled' AND p_action = 'edit_cancellation' THEN 'cancelled'::public.item_status
    WHEN v_item.status = 'cancelled' AND p_action = 'reactivate' THEN 'active'::public.item_status
    WHEN v_item.status = 'cancelled' AND p_action = 'archive' THEN 'archived'::public.item_status
    WHEN v_item.status = 'archived' AND p_action = 'reactivate' THEN 'active'::public.item_status
    WHEN v_item.status = 'trial' AND p_action = 'convert_trial' THEN 'active'::public.item_status
    WHEN v_item.status = 'trial' AND p_action = 'cancel' THEN 'cancelled'::public.item_status
    WHEN v_item.status = 'trial' AND p_action = 'trial_expired' THEN 'cancelled'::public.item_status
    ELSE NULL
  END;

  IF v_new_status IS NULL THEN
    RAISE EXCEPTION USING MESSAGE = FORMAT('Invalid status transition: %s -> %s', v_item.status, p_action);
  END IF;

  IF p_action IN ('pause', 'archive', 'start_trial') AND p_today IS NULL THEN
    RAISE EXCEPTION USING MESSAGE = 'Today is required for this status change.';
  END IF;

  IF p_action IN ('cancel', 'edit_cancellation', 'resume', 'reactivate', 'convert_trial', 'trial_expired')
     AND v_resolved_effective_date IS NULL THEN
    RAISE EXCEPTION USING MESSAGE = 'An effective date is required for this status change.';
  END IF;

  IF p_action = 'pause'
     AND p_pause_until IS NOT NULL
     AND p_today IS NOT NULL
     AND p_pause_until <= p_today THEN
    RAISE EXCEPTION USING MESSAGE = 'Auto-resume date must be after today';
  END IF;

  IF p_action = 'start_trial'
     AND p_trial_end_date IS NOT NULL
     AND p_today IS NOT NULL
     AND p_trial_end_date < p_today THEN
    RAISE EXCEPTION USING MESSAGE = 'Trial end date cannot be in the past';
  END IF;

  IF v_resolved_effective_date IS NOT NULL
     AND p_today IS NOT NULL
     AND v_resolved_effective_date > p_today THEN
    IF p_action IN ('cancel', 'edit_cancellation') THEN
      RAISE EXCEPTION USING MESSAGE = 'Cancellation dates must be today or earlier.';
    END IF;

    RAISE EXCEPTION USING MESSAGE = 'Effective dates must be today or earlier.';
  END IF;

  IF p_action IN ('resume', 'reactivate', 'convert_trial') THEN
    v_clear_fields := ARRAY[
      'paused_at',
      'paused_until',
      'cancelled_at',
      'cancellation_date',
      'archived_at',
      'trial_started_at',
      'trial_end_date'
    ]::text[];
  END IF;

  IF p_action IN ('cancel', 'edit_cancellation', 'trial_expired') THEN
    v_effective_date_floor := v_item.start_date;
  ELSIF p_action = 'resume' THEN
    SELECT MAX(candidate)
    INTO v_effective_date_floor
    FROM (VALUES (v_item.start_date), (v_item.paused_at::date)) AS candidates(candidate);
  ELSIF p_action = 'reactivate' THEN
    SELECT MAX(candidate)
    INTO v_effective_date_floor
    FROM (
      VALUES
        (v_item.start_date),
        (v_item.cancellation_date),
        (v_item.cancelled_at::date),
        (v_item.archived_at::date)
    ) AS candidates(candidate);
  ELSIF p_action = 'convert_trial' THEN
    SELECT MAX(candidate)
    INTO v_effective_date_floor
    FROM (VALUES (v_item.start_date), (v_item.trial_started_at::date)) AS candidates(candidate);
  END IF;

  IF v_resolved_effective_date IS NOT NULL
     AND v_effective_date_floor IS NOT NULL
     AND v_resolved_effective_date < v_effective_date_floor THEN
    RAISE EXCEPTION USING MESSAGE = 'Effective dates must be on or after the item''s start date.';
  END IF;

  IF p_action = 'convert_trial' AND COALESCE(v_item.amount, 0) = 0 THEN
    RAISE EXCEPTION USING MESSAGE = 'Set an amount greater than 0 before converting this trial to paid';
  END IF;

  IF p_action IN ('resume', 'reactivate', 'convert_trial') AND p_next_billing_date IS NULL THEN
    RAISE EXCEPTION USING MESSAGE = 'Next billing date is required for this status change.';
  END IF;

  IF p_action IN ('resume', 'reactivate', 'convert_trial')
     AND v_resolved_effective_date IS NOT NULL
     AND p_next_billing_date < v_resolved_effective_date THEN
    RAISE EXCEPTION USING MESSAGE = 'Next billing date must be on or after the effective date.';
  END IF;

  UPDATE public.items
  SET
    status = v_new_status,
    paused_at = CASE
      WHEN p_action = 'pause' THEN NOW()
      WHEN 'paused_at' = ANY(v_clear_fields) THEN NULL
      ELSE paused_at
    END,
    paused_until = CASE
      WHEN p_action = 'pause' THEN p_pause_until
      WHEN 'paused_until' = ANY(v_clear_fields) THEN NULL
      ELSE paused_until
    END,
    cancelled_at = CASE
      WHEN p_action IN ('cancel', 'trial_expired') THEN NOW()
      WHEN 'cancelled_at' = ANY(v_clear_fields) THEN NULL
      ELSE cancelled_at
    END,
    cancellation_date = CASE
      WHEN p_action IN ('cancel', 'edit_cancellation', 'trial_expired') THEN v_resolved_effective_date
      WHEN 'cancellation_date' = ANY(v_clear_fields) THEN NULL
      ELSE cancellation_date
    END,
    archived_at = CASE
      WHEN p_action = 'archive' THEN NOW()
      WHEN 'archived_at' = ANY(v_clear_fields) THEN NULL
      ELSE archived_at
    END,
    trial_started_at = CASE
      WHEN p_action = 'start_trial' THEN NOW()
      WHEN 'trial_started_at' = ANY(v_clear_fields) THEN NULL
      ELSE trial_started_at
    END,
    trial_end_date = CASE
      WHEN p_action = 'start_trial' THEN p_trial_end_date
      WHEN 'trial_end_date' = ANY(v_clear_fields) THEN NULL
      ELSE trial_end_date
    END,
    next_billing_date = CASE
      WHEN p_next_billing_date IS NOT NULL THEN p_next_billing_date
      WHEN 'next_billing_date' = ANY(v_clear_fields) THEN NULL
      ELSE next_billing_date
    END,
    updated_at = NOW()
  WHERE id = p_item_id
    AND user_id = v_user_id
  RETURNING *
  INTO v_updated;

  IF p_action = 'edit_cancellation' THEN
    SELECT history.id
    INTO v_authoritative_cancellation_history_id
    FROM public.item_status_history AS history
    WHERE history.item_id = p_item_id
      AND history.user_id = v_user_id
      AND (
        history.action IN ('cancel', 'trial_expired')
        OR (history.action IS NULL AND history.status = 'cancelled')
      )
    ORDER BY
      COALESCE(history.effective_date, history.changed_at::date) DESC,
      history.changed_at DESC
    LIMIT 1
    FOR UPDATE;

    IF v_authoritative_cancellation_history_id IS NULL THEN
      RAISE EXCEPTION USING MESSAGE = 'Cannot edit cancellation date without an existing cancellation history row.';
    END IF;

    UPDATE public.item_status_history
    SET effective_date = v_resolved_effective_date
    WHERE id = v_authoritative_cancellation_history_id;

    RETURN v_updated;
  END IF;

  v_history_notes := '__subtrkr_meta__:' || jsonb_build_object(
    'action', p_action,
    'effectiveDate', v_resolved_effective_date
  )::text;

  IF v_trimmed_notes IS NOT NULL THEN
    v_history_notes := v_history_notes || E'\n' || v_trimmed_notes;
  END IF;

  INSERT INTO public.item_status_history (
    item_id,
    user_id,
    status,
    reason,
    notes,
    action,
    effective_date
  )
  VALUES (
    p_item_id,
    v_user_id,
    v_new_status,
    v_trimmed_reason,
    v_history_notes,
    p_action,
    v_resolved_effective_date
  );

  RETURN v_updated;
END;
$$;

REVOKE ALL ON FUNCTION public.execute_item_status_change(
  text,
  text,
  date,
  date,
  date,
  date,
  text[],
  text,
  text,
  date,
  date
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.execute_item_status_change(
  text,
  text,
  date,
  date,
  date,
  date,
  text[],
  text,
  text,
  date,
  date
) TO authenticated;
