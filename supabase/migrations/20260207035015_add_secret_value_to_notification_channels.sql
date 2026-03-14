-- Add secret_value column to store secrets directly (replacing Vault approach)
ALTER TABLE notification_channels ADD COLUMN IF NOT EXISTS secret_value TEXT;

-- Clean up test secrets from vault
DELETE FROM vault.secrets WHERE name LIKE 'test_%';
;
