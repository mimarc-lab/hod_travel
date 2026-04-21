-- Migration 015: Subtask system
--
-- Adds:
--   subtasks            — per-task checklist items
--   subtask_templates   — default subtasks per board group (task_type)
--   tasks.subtask_count / completed_subtask_count — denormalised progress counters
--   Trigger: trg_sync_subtask_counts — keeps counters accurate on INSERT/UPDATE/DELETE

-- ── Core tables ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.subtasks (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_task_id UUID        NOT NULL REFERENCES public.tasks(id)    ON DELETE CASCADE,
  team_id        UUID        NOT NULL REFERENCES public.teams(id)     ON DELETE CASCADE,
  title          TEXT        NOT NULL CHECK (char_length(trim(title)) > 0),
  is_completed   BOOLEAN     NOT NULL DEFAULT FALSE,
  assigned_to    UUID        REFERENCES public.profiles(id)           ON DELETE SET NULL,
  order_index    INTEGER     NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.subtask_templates (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  task_type   TEXT        NOT NULL,  -- matches board group name exactly
  title       TEXT        NOT NULL,
  order_index INTEGER     NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Denormalised progress counters on tasks ───────────────────────────────────

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS subtask_count           INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS completed_subtask_count INTEGER NOT NULL DEFAULT 0;

-- ── Trigger: keep subtask_count / completed_subtask_count in sync ─────────────

CREATE OR REPLACE FUNCTION public.sync_subtask_counts()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_task_id UUID;
BEGIN
  v_task_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.parent_task_id ELSE NEW.parent_task_id END;
  UPDATE public.tasks
  SET
    subtask_count           = (SELECT COUNT(*)                                              FROM public.subtasks WHERE parent_task_id = v_task_id),
    completed_subtask_count = (SELECT COUNT(*) FROM public.subtasks WHERE parent_task_id = v_task_id AND is_completed = TRUE)
  WHERE id = v_task_id;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_subtask_counts ON public.subtasks;
CREATE TRIGGER trg_sync_subtask_counts
  AFTER INSERT OR UPDATE OR DELETE ON public.subtasks
  FOR EACH ROW EXECUTE FUNCTION public.sync_subtask_counts();

-- updated_at trigger (reuses existing set_updated_at function from 003_triggers)
DROP TRIGGER IF EXISTS trg_subtasks_updated_at ON public.subtasks;
CREATE TRIGGER trg_subtasks_updated_at
  BEFORE UPDATE ON public.subtasks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_subtasks_parent_task  ON public.subtasks(parent_task_id);
CREATE INDEX IF NOT EXISTS idx_subtasks_team_id      ON public.subtasks(team_id);
CREATE INDEX IF NOT EXISTS idx_subtask_tmpl_type     ON public.subtask_templates(task_type);

-- ── Row-level security ────────────────────────────────────────────────────────

ALTER TABLE public.subtasks          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subtask_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "subtasks: team full access"
  ON public.subtasks FOR ALL
  USING  (team_id IN (SELECT team_id FROM public.team_members WHERE user_id = auth.uid()))
  WITH CHECK (team_id IN (SELECT team_id FROM public.team_members WHERE user_id = auth.uid()));

CREATE POLICY "subtask_templates: authenticated read"
  ON public.subtask_templates FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ── Seed: default subtask templates per board group ───────────────────────────

INSERT INTO public.subtask_templates (task_type, title, order_index) VALUES
  -- Pre-Planning
  ('Pre-Planning', 'Confirm trip brief with client',          0),
  ('Pre-Planning', 'Define budget range',                     1),
  ('Pre-Planning', 'Research destination requirements',       2),
  ('Pre-Planning', 'Create initial trip framework',           3),

  -- Accommodation
  ('Accommodation', 'Identify shortlist properties',          0),
  ('Accommodation', 'Send availability requests',             1),
  ('Accommodation', 'Follow up suppliers',                    2),
  ('Accommodation', 'Review responses and pricing',           3),
  ('Accommodation', 'Narrow to final options',                4),
  ('Accommodation', 'Confirm booking and get voucher',        5),

  -- Experiences
  ('Experiences', 'Research experience options',              0),
  ('Experiences', 'Get quotes from operators',                1),
  ('Experiences', 'Confirm logistics (timing, transport)',    2),
  ('Experiences', 'Book and receive confirmation',            3),
  ('Experiences', 'Add to itinerary',                        4),

  -- Logistics
  ('Logistics', 'Identify transport requirements',            0),
  ('Logistics', 'Source vehicle / transfer options',          1),
  ('Logistics', 'Confirm bookings',                           2),
  ('Logistics', 'Share details with client',                  3),

  -- Finance
  ('Finance', 'Collect supplier invoices',                    0),
  ('Finance', 'Verify amounts against proposal',              1),
  ('Finance', 'Process payments',                             2),
  ('Finance', 'Update budget tracker',                        3),

  -- Client Delivery
  ('Client Delivery', 'Compile final itinerary document',     0),
  ('Client Delivery', 'Add all booking confirmations',        1),
  ('Client Delivery', 'Internal review',                      2),
  ('Client Delivery', 'Send to client',                       3),
  ('Client Delivery', 'Collect client sign-off',              4)

ON CONFLICT DO NOTHING;
