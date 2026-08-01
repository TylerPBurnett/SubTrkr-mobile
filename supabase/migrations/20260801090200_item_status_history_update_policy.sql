-- Correctness Fix: allow users to UPDATE their own item_status_history rows
--
-- public.execute_item_status_change is SECURITY INVOKER, so every statement it
-- runs is subject to the caller's RLS policies. Its `edit_cancellation` branch
-- runs:
--   UPDATE public.item_status_history SET effective_date = ... WHERE id = ...
-- but item_status_history only had SELECT and INSERT policies (see
-- 20260205164724_optimize_rls_policies_performance.sql). With RLS enabled and no
-- UPDATE policy, the UPDATE matches 0 rows and raises no error -- the item's
-- cancellation_date is corrected while the audit trail silently keeps the stale
-- effective_date.
--
-- auth.uid() is wrapped in SELECT so Postgres evaluates it once per query rather
-- than once per row, matching the other policies on this table.
-- Reference: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

DROP POLICY IF EXISTS "Users can update their own item status history" ON public.item_status_history;
CREATE POLICY "Users can update their own item status history"
  ON public.item_status_history
  FOR UPDATE
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));
