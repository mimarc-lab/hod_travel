-- ─────────────────────────────────────────────────────────────────────────────
-- Run Sheet Share — Anon RLS Policies
--
-- Run these in the Supabase SQL editor so that unauthenticated viewers can
-- access the data behind a shared run sheet link.
-- ─────────────────────────────────────────────────────────────────────────────


-- 1. Allow anon to read active (non-revoked) share tokens
--    Needed so the app can validate the token before showing any data.
CREATE POLICY "anon can read active run sheet tokens"
  ON public.run_sheet_share_tokens
  FOR SELECT
  TO anon
  USING (revoked_at IS NULL);


-- 2. Allow anon to read trips that have at least one active run sheet token
--    Skip if a permissive anon SELECT policy already exists on this table.
CREATE POLICY "anon can read trips with active run sheet token"
  ON public.trips
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1
      FROM public.run_sheet_share_tokens st
      WHERE st.trip_id = trips.id
        AND st.revoked_at IS NULL
    )
  );


-- 3. Allow anon to read trip_destinations for those trips
--    Skip if a permissive anon SELECT policy already exists on this table.
CREATE POLICY "anon can read trip destinations for run sheet share"
  ON public.trip_destinations
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1
      FROM public.run_sheet_share_tokens st
      WHERE st.trip_id = trip_destinations.trip_id
        AND st.revoked_at IS NULL
    )
  );


-- 4. Allow anon to read trip_days for those trips
--    Skip if a permissive anon SELECT policy already exists on this table.
CREATE POLICY "anon can read trip days for run sheet share"
  ON public.trip_days
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1
      FROM public.run_sheet_share_tokens st
      WHERE st.trip_id = trip_days.trip_id
        AND st.revoked_at IS NULL
    )
  );


-- 5. Allow anon to read itinerary_items for those trips
--    Skip if a permissive anon SELECT policy already exists on this table.
CREATE POLICY "anon can read itinerary items for run sheet share"
  ON public.itinerary_items
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1
      FROM public.run_sheet_share_tokens st
      WHERE st.trip_id = itinerary_items.trip_id
        AND st.revoked_at IS NULL
    )
  );


-- 6. Allow anon to read run_sheet_items for those trips
--    This table is specific to run sheets and likely has no anon policy yet.
CREATE POLICY "anon can read run sheet items for run sheet share"
  ON public.run_sheet_items
  FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1
      FROM public.run_sheet_share_tokens st
      WHERE st.trip_id = run_sheet_items.trip_id
        AND st.revoked_at IS NULL
    )
  );
