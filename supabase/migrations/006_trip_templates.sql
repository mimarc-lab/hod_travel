-- =============================================================================
-- 006_trip_templates.sql
--
-- Adds trip_templates and trip_template_tasks tables.
-- Templates are scoped to a team and can be reused for future trips.
-- =============================================================================

-- ── trip_templates ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS trip_templates (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id      UUID        NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  created_by   UUID        REFERENCES profiles(id) ON DELETE SET NULL,
  name         TEXT        NOT NULL,
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── trip_template_tasks ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS trip_template_tasks (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id  UUID        NOT NULL REFERENCES trip_templates(id) ON DELETE CASCADE,
  group_name   TEXT        NOT NULL,   -- matches board group name (e.g. 'Accommodation')
  title        TEXT        NOT NULL,
  priority     TEXT        NOT NULL DEFAULT 'medium'
                           CHECK (priority IN ('low', 'medium', 'high')),
  sort_order   INT         NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_trip_templates_team
  ON trip_templates(team_id);

CREATE INDEX IF NOT EXISTS idx_trip_template_tasks_template
  ON trip_template_tasks(template_id, sort_order);

-- ── updated_at trigger ────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_trip_templates_updated_at ON trip_templates;
CREATE TRIGGER set_trip_templates_updated_at
  BEFORE UPDATE ON trip_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── RLS ───────────────────────────────────────────────────────────────────────

ALTER TABLE trip_templates      ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_template_tasks ENABLE ROW LEVEL SECURITY;

-- trip_templates: team members can read; admins can write
CREATE POLICY "team members can view templates"
  ON trip_templates FOR SELECT
  USING (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

CREATE POLICY "team members can create templates"
  ON trip_templates FOR INSERT
  WITH CHECK (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

CREATE POLICY "team members can update templates"
  ON trip_templates FOR UPDATE
  USING (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

CREATE POLICY "team members can delete templates"
  ON trip_templates FOR DELETE
  USING (
    team_id IN (
      SELECT team_id FROM team_members
      WHERE user_id = auth.uid() AND is_active = true
    )
  );

-- trip_template_tasks: inherit access via template
CREATE POLICY "team members can view template tasks"
  ON trip_template_tasks FOR SELECT
  USING (
    template_id IN (
      SELECT id FROM trip_templates
      WHERE team_id IN (
        SELECT team_id FROM team_members
        WHERE user_id = auth.uid() AND is_active = true
      )
    )
  );

CREATE POLICY "team members can create template tasks"
  ON trip_template_tasks FOR INSERT
  WITH CHECK (
    template_id IN (
      SELECT id FROM trip_templates
      WHERE team_id IN (
        SELECT team_id FROM team_members
        WHERE user_id = auth.uid() AND is_active = true
      )
    )
  );

CREATE POLICY "team members can update template tasks"
  ON trip_template_tasks FOR UPDATE
  USING (
    template_id IN (
      SELECT id FROM trip_templates
      WHERE team_id IN (
        SELECT team_id FROM team_members
        WHERE user_id = auth.uid() AND is_active = true
      )
    )
  );

CREATE POLICY "team members can delete template tasks"
  ON trip_template_tasks FOR DELETE
  USING (
    template_id IN (
      SELECT id FROM trip_templates
      WHERE team_id IN (
        SELECT team_id FROM team_members
        WHERE user_id = auth.uid() AND is_active = true
      )
    )
  );
