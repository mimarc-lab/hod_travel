-- =============================================================================
-- 024_itinerary_realtime.sql
-- Enable realtime for trip_days and itinerary_items (idempotent)
-- =============================================================================

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
