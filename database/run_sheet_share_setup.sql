-- ─────────────────────────────────────────────────────────────────────────────
-- Run Sheet Share — Full Setup
-- Run this entire script in the Supabase SQL editor (one paste, one run).
-- ─────────────────────────────────────────────────────────────────────────────


-- ── 1. Create table ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.run_sheet_share_tokens (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id     UUID        NOT NULL REFERENCES public.trips(id)    ON DELETE CASCADE,
  team_id     UUID        NOT NULL REFERENCES public.teams(id)    ON DELETE CASCADE,
  token       TEXT        NOT NULL UNIQUE
                            DEFAULT encode(gen_random_bytes(18), 'base64url'),
  view_mode   TEXT        NOT NULL DEFAULT 'director',
  label       TEXT,
  expires_at  TIMESTAMPTZ,
  created_by  UUID        REFERENCES public.profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_run_sheet_share_tokens_token
  ON public.run_sheet_share_tokens (token)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_run_sheet_share_tokens_trip_id
  ON public.run_sheet_share_tokens (trip_id);


-- ── 2. Enable RLS ─────────────────────────────────────────────────────────────

ALTER TABLE public.run_sheet_share_tokens ENABLE ROW LEVEL SECURITY;


-- ── 3. Authenticated policies (staff who generate tokens) ─────────────────────

CREATE POLICY "authenticated can insert run sheet tokens"
  ON public.run_sheet_share_tokens
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "authenticated can read run sheet tokens"
  ON public.run_sheet_share_tokens
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "authenticated can revoke own run sheet tokens"
  ON public.run_sheet_share_tokens
  FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid());


-- ── 4. Anon policies (recipients who open a share link) ───────────────────────

-- 4a. Token lookup — anon can read active tokens (validates the share link)
CREATE POLICY "anon can read active run sheet tokens"
  ON public.run_sheet_share_tokens
  FOR SELECT
  TO anon
  USING (revoked_at IS NULL);

-- 4b. Trips — anon can read trips that have an active run sheet token
--     (Skip with: IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = '...'))
CREATE POLICY "anon can read trips with run sheet token"
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

-- 4c. Trip destinations
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

-- 4d. Trip days
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

-- 4e. Itinerary items
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

-- 4f. Run sheet items (execution overlay — statuses, notes, instructions)
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
