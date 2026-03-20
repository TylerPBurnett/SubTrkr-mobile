ALTER TABLE public.item_status_history
  ADD COLUMN action TEXT,
  ADD COLUMN effective_date DATE;

CREATE INDEX idx_item_status_history_item_effective_date
  ON public.item_status_history (item_id, effective_date DESC)
  WHERE effective_date IS NOT NULL;

COMMENT ON COLUMN public.item_status_history.action IS
  'Canonical lifecycle action for this history row.';

COMMENT ON COLUMN public.item_status_history.effective_date IS
  'Date the lifecycle change took effect in the real world.';
