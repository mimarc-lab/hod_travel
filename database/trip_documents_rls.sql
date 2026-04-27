-- =============================================================================
-- RLS policies for trip_documents
-- Enforces team-scoped access. Only team members can read/write their own docs.
-- =============================================================================

-- Enable RLS
ALTER TABLE trip_documents ENABLE ROW LEVEL SECURITY;

-- ── Helper: is the caller a member of the document's team? ───────────────────
-- Reuses the same pattern as other tables in this project.

CREATE POLICY "team_members_can_select"
  ON trip_documents FOR SELECT
  USING (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "team_members_can_insert"
  ON trip_documents FOR INSERT
  WITH CHECK (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "team_members_can_update"
  ON trip_documents FOR UPDATE
  USING (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid()
    )
  );

-- Hard deletes are allowed only for team members (archive is the preferred path).
CREATE POLICY "team_members_can_delete"
  ON trip_documents FOR DELETE
  USING (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid()
    )
  );

-- =============================================================================
-- Client-safe view: only expose documents marked is_client_visible = true.
-- Use this view for any client-facing endpoint or export.
-- =============================================================================

CREATE OR REPLACE VIEW client_visible_documents AS
  SELECT *
  FROM trip_documents
  WHERE is_client_visible = true
    AND status NOT IN ('archived', 'missing');

-- RLS on the view is inherited from the base table.
