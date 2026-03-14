-- Security Fix: Set search_path on update_updated_at_column function
-- This prevents potential search_path hijacking attacks
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path = ''
AS $function$
  BEGIN
    NEW.updated_at = now();
    RETURN NEW;
  END;
$function$;
;
