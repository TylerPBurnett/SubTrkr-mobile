-- =====================================================
-- Security Fix: Lock down public.get_items_due_for_notification()
-- =====================================================
--
-- Problem:
--   get_items_due_for_notification() is SECURITY DEFINER and returns rows for
--   EVERY user (it deliberately ignores RLS so the notification dispatcher can
--   see the whole fleet). PostgREST exposes any function in the `public` schema
--   at /rest/v1/rpc/<name>, so with default privileges any anon or authenticated
--   caller could POST to that endpoint and read every user's items -- name,
--   amount, currency, billing dates. That is a cross-tenant data leak.
--
-- Fix:
--   Remove EXECUTE from everyone, then hand it back to service_role only.
--
-- Why revoking PUBLIC alone is NOT enough:
--   Supabase ships ALTER DEFAULT PRIVILEGES that GRANT EXECUTE on newly created
--   functions in `public` directly to the anon, authenticated and service_role
--   roles. Those are explicit per-role grants in the function ACL, not the
--   implicit PUBLIC grant, so `REVOKE ... FROM PUBLIC` leaves them in place.
--   Each role has to be revoked by name.
--
-- Why the GRANT to service_role is mandatory:
--   The send-notifications edge function calls this RPC with the service role
--   key. service_role has BYPASSRLS, but BYPASSRLS only bypasses row level
--   security policies -- it does NOT bypass function EXECUTE privileges (ACLs).
--   Without the grant below, notification dispatch breaks with
--   "permission denied for function get_items_due_for_notification".
--   service_role is also not a superuser, so it gets no implicit pass.

REVOKE ALL ON FUNCTION public.get_items_due_for_notification() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_items_due_for_notification() FROM anon;
REVOKE ALL ON FUNCTION public.get_items_due_for_notification() FROM authenticated;

-- Required: the send-notifications edge function is the only intended caller.
GRANT EXECUTE ON FUNCTION public.get_items_due_for_notification() TO service_role;
