-- =============================================================================
-- 023_cost_item_deposit.sql
-- Add deposit_paid column to cost_items
-- =============================================================================

ALTER TABLE cost_items
  ADD COLUMN IF NOT EXISTS deposit_paid NUMERIC(12,2) NOT NULL DEFAULT 0;

-- Enable realtime for cost_items if not already (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename  = 'cost_items'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE cost_items;
  END IF;
END $$;
