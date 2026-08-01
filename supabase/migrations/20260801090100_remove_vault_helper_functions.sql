-- =====================================================
-- Security Fix: Remove the legacy public Vault helper functions
-- =====================================================
--
-- Problem:
--   20260206040044_add_vault_helper_functions.sql created three SECURITY DEFINER
--   functions in the `public` schema with default privileges, i.e. EXECUTE for
--   PUBLIC/anon/authenticated:
--     - public.create_secret(text, text)
--     - public.get_decrypted_secret(uuid)
--     - public.delete_secret(uuid)
--   PostgREST exposes them at /rest/v1/rpc/<name>. Because they are SECURITY
--   DEFINER they run as the owner, so ANY caller could write arbitrary rows into
--   vault.secrets, read back any decrypted secret whose UUID they can guess or
--   obtain, or delete secrets -- including the `project_url` / `anon_key`
--   secrets the pg_cron notification job depends on.
--
-- Why dropping (rather than revoking) is safe:
--   Nothing in either repo calls these functions.
--     * Notification secrets moved to notification_channels.secret_value in
--       20260207035015_add_secret_value_to_notification_channels.sql, protected
--       by that table's RLS policy.
--     * The pg_cron job reads vault.decrypted_secrets directly as the postgres
--       role (see the schedule block in
--       20260208195618_add_timezone_aware_notifications.sql); it never goes
--       through these helpers.
--     * The only remaining `create_secret` hits in the repos are
--       `vault.create_secret(...)` in docs/notifications/NOTIFICATION_SETUP.md
--       and docs/reference/enable-cron.sql -- that is the built-in Vault
--       function in the `vault` schema, which is unaffected by these DROPs.
--   Vault itself keeps working; only the unauthenticated public wrappers go away.

DROP FUNCTION IF EXISTS public.create_secret(text, text);
DROP FUNCTION IF EXISTS public.get_decrypted_secret(uuid);
DROP FUNCTION IF EXISTS public.delete_secret(uuid);
