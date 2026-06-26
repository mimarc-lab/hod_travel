-- =============================================================================
-- 026_client_media_rpc.sql
--
-- Creates get_client_media_for_trip(trip_id) — a SECURITY DEFINER function
-- that allows the anon role to fetch client-safe media for a trip.
--
-- Without this, anon clients (public share links) cannot access trip_components
-- or component_media (both protected by authenticated-only RLS policies).
-- This function joins those tables server-side, exposing only the safe
-- presentation columns (no booking refs, costs, or internal data).
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
    )                                                              AS caption,
    cm.is_hero,
    cm.display_order
  FROM   trip_components  tc
  JOIN   component_media  cm ON cm.component_id      = tc.id
  JOIN   supplier_media   sm ON sm.id                = cm.supplier_media_id
  WHERE  tc.trip_id       = p_trip_id
    AND  tc.itinerary_item_id IS NOT NULL
    AND  cm.is_visible    = true
    AND  sm.is_active     = true
  ORDER BY cm.is_hero DESC NULLS LAST,
           cm.display_order ASC NULLS LAST,
           cm.created_at    ASC NULLS LAST;
$$;

-- Allow both anon (public share links) and authenticated users to call this.
GRANT EXECUTE ON FUNCTION get_client_media_for_trip(uuid) TO anon, authenticated;
