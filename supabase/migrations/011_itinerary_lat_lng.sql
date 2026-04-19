-- =============================================================================
-- 011_itinerary_lat_lng.sql
-- Adds optional explicit coordinates to itinerary items so map pins can be
-- placed precisely rather than relying on location-string geocoding.
-- =============================================================================

ALTER TABLE public.itinerary_items
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
