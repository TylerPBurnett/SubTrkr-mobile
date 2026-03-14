-- Performance Fix: Add index on items.category_id foreign key
-- This improves join performance and foreign key constraint checks
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys

CREATE INDEX IF NOT EXISTS idx_items_category_id ON items(category_id);
;
