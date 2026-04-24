-- ─────────────────────────────────────────────────────────────────────────────
-- 020_trip_components.sql
-- Trip components — accommodation, experiences, dining, transport, etc.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Enums ──────────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE component_type_enum AS ENUM (
    'accommodation', 'experience', 'dining', 'transport',
    'guide', 'flight', 'train', 'yacht', 'special_arrangement', 'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE component_status_enum AS ENUM (
    'proposed', 'approved', 'confirmed', 'booked', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Table ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trip_components (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id             UUID NOT NULL REFERENCES trips(id)        ON DELETE CASCADE,
  team_id             UUID NOT NULL REFERENCES teams(id)        ON DELETE CASCADE,
  component_type      component_type_enum   NOT NULL DEFAULT 'other',
  status              component_status_enum NOT NULL DEFAULT 'proposed',
  title               TEXT NOT NULL,
  supplier_id         UUID REFERENCES suppliers(id) ON DELETE SET NULL,
  start_date          DATE,
  end_date            DATE,
  start_time          TIME,
  end_time            TIME,
  location_name       TEXT,
  address             TEXT,
  notes_internal      TEXT,
  notes_client        TEXT,
  cost_item_id        UUID REFERENCES cost_items(id)       ON DELETE SET NULL,
  itinerary_item_id   UUID REFERENCES itinerary_items(id)  ON DELETE SET NULL,
  run_sheet_item_id   UUID,
  created_by          UUID REFERENCES profiles(id)         ON DELETE SET NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Indexes ────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_trip_components_trip_id   ON trip_components(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_components_team_id   ON trip_components(team_id);
CREATE INDEX IF NOT EXISTS idx_trip_components_status    ON trip_components(status);
CREATE INDEX IF NOT EXISTS idx_trip_components_type      ON trip_components(component_type);

-- ── updated_at trigger ─────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_trip_components_updated_at ON trip_components;
CREATE TRIGGER trg_trip_components_updated_at
  BEFORE UPDATE ON trip_components
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── RLS ────────────────────────────────────────────────────────────────────
ALTER TABLE trip_components ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "team_members_read_components"   ON trip_components;
DROP POLICY IF EXISTS "team_members_write_components"  ON trip_components;
DROP POLICY IF EXISTS "team_members_delete_components" ON trip_components;

CREATE POLICY "team_members_read_components"
  ON trip_components FOR SELECT
  USING (
    team_id IN (
      SELECT team_id FROM team_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "team_members_write_components"
  ON trip_components FOR INSERT
  WITH CHECK (
    team_id IN (
      SELECT team_id FROM team_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "team_members_update_components"
  ON trip_components FOR UPDATE
  USING (
    team_id IN (
      SELECT team_id FROM team_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "team_members_delete_components"
  ON trip_components FOR DELETE
  USING (
    team_id IN (
      SELECT team_id FROM team_members WHERE user_id = auth.uid()
    )
  );
