-- Performance Fix: Optimize RLS policies to prevent auth function re-evaluation
-- Wrapping auth.uid() in SELECT makes Postgres evaluate it once per query instead of once per row
-- Reference: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

-- 1. Optimize categories table policy
DROP POLICY IF EXISTS "Users manage own categories" ON categories;
CREATE POLICY "Users manage own categories"
  ON categories
  FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 2. Optimize items table policy
DROP POLICY IF EXISTS "Users manage own items" ON items;
CREATE POLICY "Users manage own items"
  ON items
  FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 3. Optimize payments table policy
DROP POLICY IF EXISTS "Users manage own payments" ON payments;
CREATE POLICY "Users manage own payments"
  ON payments
  FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 4. Optimize item_status_history SELECT policy
DROP POLICY IF EXISTS "Users can view their own item status history" ON item_status_history;
CREATE POLICY "Users can view their own item status history"
  ON item_status_history
  FOR SELECT
  USING (user_id = (SELECT auth.uid()));

-- 5. Optimize item_status_history INSERT policy
DROP POLICY IF EXISTS "Users can insert status history for their own items" ON item_status_history;
CREATE POLICY "Users can insert status history for their own items"
  ON item_status_history
  FOR INSERT
  WITH CHECK (user_id = (SELECT auth.uid()));
;
