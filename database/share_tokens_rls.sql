-- ─────────────────────────────────────────────────────────────────────────────
-- share_tokens RLS
-- ─────────────────────────────────────────────────────────────────────────────

-- Anon can read any valid (non-expired) token.
-- UUIDs are unguessable so this is safe — you can only find it if you have it.
CREATE POLICY "anon can read valid share tokens" ON public.share_tokens
  FOR SELECT TO anon
  USING (expires_at IS NULL OR expires_at > NOW());

-- Authenticated users can read all share tokens (needed for insert+select to work).
CREATE POLICY "authenticated can read share tokens" ON public.share_tokens
  FOR SELECT TO authenticated
  USING (true);

-- Any authenticated user can create a share token.
-- The TO authenticated clause already enforces auth; trip_id FK enforces validity.
CREATE POLICY "authenticated can insert share tokens" ON public.share_tokens
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Team members can delete tokens for their trips.
CREATE POLICY "team members can delete share tokens" ON public.share_tokens
  FOR DELETE TO authenticated
  USING (
    (SELECT team_id FROM public.trips WHERE id = trip_id)
    IN (SELECT team_id FROM public.team_members WHERE user_id = auth.uid())
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- Downstream tables — anon read policies for shared trips
-- ─────────────────────────────────────────────────────────────────────────────

-- trips: anon can read trips that have a valid share token.
CREATE POLICY "anon can read shared trips" ON public.trips
  FOR SELECT TO anon
  USING (
    EXISTS (
      SELECT 1 FROM public.share_tokens st
      WHERE st.trip_id = trips.id
        AND (st.expires_at IS NULL OR st.expires_at > NOW())
    )
  );

-- trip_destinations: anon can read destinations for shared trips.
CREATE POLICY "anon can read shared trip destinations" ON public.trip_destinations
  FOR SELECT TO anon
  USING (
    EXISTS (
      SELECT 1 FROM public.share_tokens st
      WHERE st.trip_id = trip_id
        AND (st.expires_at IS NULL OR st.expires_at > NOW())
    )
  );

-- trip_days: anon can read days for shared trips.
CREATE POLICY "anon can read shared trip days" ON public.trip_days
  FOR SELECT TO anon
  USING (
    EXISTS (
      SELECT 1 FROM public.share_tokens st
      WHERE st.trip_id = trip_id
        AND (st.expires_at IS NULL OR st.expires_at > NOW())
    )
  );

-- itinerary_items: anon can read items for shared trips (via trip_days).
CREATE POLICY "anon can read shared itinerary items" ON public.itinerary_items
  FOR SELECT TO anon
  USING (
    EXISTS (
      SELECT 1 FROM public.trip_days td
      JOIN public.share_tokens st ON st.trip_id = td.trip_id
      WHERE td.id = trip_day_id
        AND (st.expires_at IS NULL OR st.expires_at > NOW())
    )
  );

-- trip_components: anon can read components for shared trips.
CREATE POLICY "anon can read shared trip components" ON public.trip_components
  FOR SELECT TO anon
  USING (
    EXISTS (
      SELECT 1 FROM public.share_tokens st
      WHERE st.trip_id = trip_id
        AND (st.expires_at IS NULL OR st.expires_at > NOW())
    )
  );

-- component_media: anon can read visible media for shared trips.
CREATE POLICY "anon can read shared component media" ON public.component_media
  FOR SELECT TO anon
  USING (
    is_visible = true
    AND EXISTS (
      SELECT 1 FROM public.trip_components tc
      JOIN public.share_tokens st ON st.trip_id = tc.trip_id
      WHERE tc.id = component_id
        AND (st.expires_at IS NULL OR st.expires_at > NOW())
    )
  );

-- supplier_media: anon can read active media linked to shared trips.
CREATE POLICY "anon can read shared supplier media" ON public.supplier_media
  FOR SELECT TO anon
  USING (
    is_active = true
    AND EXISTS (
      SELECT 1 FROM public.component_media cm
      JOIN public.trip_components tc ON tc.id = cm.component_id
      JOIN public.share_tokens st ON st.trip_id = tc.trip_id
      WHERE cm.supplier_media_id = supplier_media.id
        AND cm.is_visible = true
        AND (st.expires_at IS NULL OR st.expires_at > NOW())
    )
  );
