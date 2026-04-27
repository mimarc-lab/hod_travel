-- =============================================================================
-- trip_documents — structured document/attachment layer for HOD Travel
-- Run this in Supabase SQL editor (Dashboard → SQL Editor → New query)
-- =============================================================================

CREATE TABLE IF NOT EXISTS trip_documents (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id           UUID        NOT NULL REFERENCES teams(id)            ON DELETE CASCADE,
  trip_id           UUID        NOT NULL REFERENCES trips(id)            ON DELETE CASCADE,

  -- ── Link fields (all optional — a document may be trip-level only) ────────
  component_id      UUID        REFERENCES trip_components(id)           ON DELETE SET NULL,
  cost_item_id      UUID        REFERENCES cost_items(id)                ON DELETE SET NULL,
  run_sheet_item_id UUID        REFERENCES run_sheet_items(id)           ON DELETE SET NULL,
  supplier_id       UUID        REFERENCES suppliers(id)                 ON DELETE SET NULL,
  itinerary_item_id UUID        REFERENCES itinerary_items(id)           ON DELETE SET NULL,

  -- ── Document fields ───────────────────────────────────────────────────────
  document_type     TEXT        NOT NULL DEFAULT 'other',
  title             TEXT        NOT NULL,
  file_url          TEXT        NOT NULL,
  file_name         TEXT,
  file_size         BIGINT,
  mime_type         TEXT,
  storage_path      TEXT,

  -- ── Status ────────────────────────────────────────────────────────────────
  status            TEXT        NOT NULL DEFAULT 'uploaded',
  is_client_visible BOOLEAN     NOT NULL DEFAULT false,

  -- ── Dates ─────────────────────────────────────────────────────────────────
  issue_date        DATE,
  expiry_date       DATE,
  uploaded_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at       TIMESTAMPTZ,
  approved_at       TIMESTAMPTZ,

  -- ── Ownership ─────────────────────────────────────────────────────────────
  uploaded_by       UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_by       UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_by       UUID        REFERENCES auth.users(id) ON DELETE SET NULL,

  -- ── Notes ─────────────────────────────────────────────────────────────────
  notes_internal    TEXT,
  notes_client      TEXT,

  -- ── Constraints ───────────────────────────────────────────────────────────
  CONSTRAINT trip_documents_type_check   CHECK (document_type IN (
    'booking_confirmation','invoice','voucher','contract','permit','receipt',
    'payment_confirmation','insurance','waiver','supplier_terms','passport_or_id','other'
  )),
  CONSTRAINT trip_documents_status_check CHECK (status IN (
    'uploaded','reviewed','approved','expired','missing','archived'
  ))
);

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS trip_documents_trip_id_idx
  ON trip_documents(trip_id);

CREATE INDEX IF NOT EXISTS trip_documents_team_id_idx
  ON trip_documents(team_id);

CREATE INDEX IF NOT EXISTS trip_documents_component_id_idx
  ON trip_documents(component_id) WHERE component_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS trip_documents_cost_item_id_idx
  ON trip_documents(cost_item_id) WHERE cost_item_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS trip_documents_run_sheet_item_id_idx
  ON trip_documents(run_sheet_item_id) WHERE run_sheet_item_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS trip_documents_supplier_id_idx
  ON trip_documents(supplier_id) WHERE supplier_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS trip_documents_status_idx
  ON trip_documents(status);

CREATE INDEX IF NOT EXISTS trip_documents_expiry_date_idx
  ON trip_documents(expiry_date) WHERE expiry_date IS NOT NULL;

-- ── Enable realtime ───────────────────────────────────────────────────────────
-- Allows the app to subscribe to document changes via Supabase channels.

ALTER PUBLICATION supabase_realtime ADD TABLE trip_documents;
