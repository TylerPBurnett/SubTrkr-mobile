
-- Helper function to create a secret in vault (callable via RPC from Edge Functions)
CREATE OR REPLACE FUNCTION public.create_secret(name TEXT, secret TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  secret_id UUID;
BEGIN
  INSERT INTO vault.secrets (name, secret)
  VALUES (create_secret.name, create_secret.secret)
  RETURNING id INTO secret_id;
  RETURN secret_id;
END;
$$;

-- Helper function to get a decrypted secret from vault
CREATE OR REPLACE FUNCTION public.get_decrypted_secret(secret_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  result TEXT;
BEGIN
  SELECT decrypted_secret INTO result
  FROM vault.decrypted_secrets
  WHERE id = get_decrypted_secret.secret_id;
  RETURN result;
END;
$$;

-- Helper function to delete a secret from vault
CREATE OR REPLACE FUNCTION public.delete_secret(secret_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  DELETE FROM vault.secrets WHERE id = delete_secret.secret_id;
END;
$$;
;
