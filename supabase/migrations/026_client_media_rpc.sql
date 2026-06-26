-- =============================================================================
-- 026_client_media_rpc.sql
--
-- Creates get_client_media_for_trip(trip_id) — a SECURITY DEFINER function
-- that allows the anon role to fetch client-safe media for a trip.
--
-- Covers two image sources:
--   Path 1 — Component media: trip_components → component_media → supplier_media
--             (images added via the Components tab)
--   Path 2 — Gallery selection: itinerary_items.gallery_media_ids → supplier_media
--             (images selected via the gallery picker in the Itinerary item editor)
-- =============================================================================

CREATE OR REPLACE FUNCTION get_client_media_for_trip(p_trip_id uuid)
RETURNS TABLE (
  itinerary_item_id text,
  media_type        text,
  file_url          text,
  thumbnail_url     text,
  video_url         text,
  caption           text,
  is_hero           boolean,
  display_order     integer
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  -- Path 1: Images attached to trip components
  SELECT
    tc.itinerary_item_id::text,
    COALESCE(sm.media_type, 'image')                              AS media_type,
    sm.file_url,
    sm.thumbnail_url,
    sm.video_url,
    COALESCE(
      NULLIF(TRIM(cm.caption_override), ''),
      NULLIF(TRIM(sm.caption), ''),
      NULLIF(TRIM(sm.title), '')
    )                                                             AS caption,
    cm.is_hero,
    cm.display_order
  FROM   trip_components  tc
  JOIN   component_media  cm ON cm.component_id      = tc.id
  JOIN   supplier_media   sm ON sm.id                = cm.supplier_media_id
  WHERE  tc.trip_id       = p_trip_id
    AND  tc.itinerary_item_id IS NOT NULL
    AND  cm.is_visible    = true
    AND  sm.is_active     = true

  UNION ALL

  -- Path 2: Images selected via the gallery picker on itinerary items
  --         (only for items that have no component media, to avoid duplicates)
  SELECT
    ii.id::text                                                   AS itinerary_item_id,
    COALESCE(sm.media_type, 'image')                              AS media_type,
    sm.file_url,
    sm.thumbnail_url,
    sm.video_url,
    COALESCE(
      NULLIF(TRIM(sm.caption), ''),
      NULLIF(TRIM(sm.title), '')
    )                                                             AS caption,
    sm.is_hero,
    sm.display_order
  FROM   trip_days       td
  JOIN   itinerary_items ii ON ii.trip_day_id  = td.id
  JOIN   supplier_media  sm ON sm.id::text     = ANY(ii.gallery_media_ids::text[])
  WHERE  td.trip_id      = p_trip_id
    AND  ii.gallery_media_ids IS NOT NULL
    AND  array_length(ii.gallery_media_ids, 1) > 0
    AND  sm.is_active    = true
    AND  NOT EXISTS (
      SELECT 1
      FROM   trip_components  tc2
      JOIN   component_media  cm2 ON cm2.component_id = tc2.id
      WHERE  tc2.trip_id            = p_trip_id
        AND  tc2.itinerary_item_id  = ii.id
        AND  cm2.is_visible         = true
    )

  ORDER BY is_hero DESC NULLS LAST,
           display_order ASC NULLS LAST;
$$;

-- Allow both anon (public share links) and authenticated users to call this.
GRANT EXECUTE ON FUNCTION get_client_media_for_trip(uuid) TO anon, authenticated;
