-- =============================================================================
-- 024_itinerary_realtime.sql  (idempotent — safe to re-run)
-- Enable realtime for trip_days and itinerary_items.
--
-- REPLICA IDENTITY FULL is required so Supabase realtime can include all
-- column values in WAL events. Without it, filtered subscriptions on
-- non-primary-key columns (trip_id, team_id) silently drop events.
-- =============================================================================

-- trip_days ───────────────────────────────────────────────────────────────────

ALTER TABLE trip_days REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname    = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename  = 'trip_days'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE trip_days;
  END IF;
END $$;

-- itinerary_items ─────────────────────────────────────────────────────────────

ALTER TABLE itinerary_items REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname    = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename  = 'itinerary_items'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE itinerary_items;
  END IF;
END $$;

-- Also apply REPLICA IDENTITY FULL to tables added in earlier migrations
-- so their filtered subscriptions are equally reliable.

ALTER TABLE trip_components REPLICA IDENTITY FULL;
ALTER TABLE cost_items      REPLICA IDENTITY FULL;
