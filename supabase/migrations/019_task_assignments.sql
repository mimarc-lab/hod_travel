-- Migration 019: Task Assignments — many-to-many task ↔ user model
--
-- Replaces the single tasks.assigned_to column with a junction table that
-- supports multiple assignees per task, each with a role and a primary flag.
--
-- Backward compat strategy:
--   • tasks.assigned_to is kept and auto-synced with the primary assignment
--     via trg_sync_assignment_to_task (new API → tasks)
--   • trg_sync_task_assigned_to keeps task_assignments in sync when legacy
--     code writes directly to tasks.assigned_to (trip creation service, etc.)
--   • Both triggers guard against recursive firing with pg_trigger_depth() > 1

-- ── 1. Junction table ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.task_assignments (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id         UUID        NOT NULL REFERENCES public.tasks(id)    ON DELETE CASCADE,
  user_id         UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  assignment_role TEXT        NOT NULL DEFAULT 'collaborator'
                              CHECK (assignment_role IN ('lead', 'collaborator')),
  is_primary      BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (task_id, user_id)
);

-- Enforce one primary assignee per task
CREATE UNIQUE INDEX IF NOT EXISTS idx_task_assignments_one_primary
  ON public.task_assignments(task_id) WHERE is_primary = TRUE;

CREATE INDEX IF NOT EXISTS idx_task_assignments_task_id ON public.task_assignments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_user_id ON public.task_assignments(user_id);

-- ── 2. Row-level security ─────────────────────────────────────────────────────

ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "task_assignments: team full access"
  ON public.task_assignments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.tasks t
      JOIN  public.team_members tm ON tm.team_id = t.team_id
      WHERE t.id = task_id AND tm.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.tasks t
      JOIN  public.team_members tm ON tm.team_id = t.team_id
      WHERE t.id = task_id AND tm.user_id = auth.uid()
    )
  );

-- ── 3. Trigger A: task_assignments → tasks ────────────────────────────────────
-- Keeps tasks.assigned_to = current primary assignee (or NULL).
-- Also touches updated_at so watchGroupsForTrip realtime fires for
-- collaborator additions that don't change the primary.

CREATE OR REPLACE FUNCTION public.sync_assignment_to_task()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_task_id    UUID;
  v_primary_user UUID;
BEGIN
  IF pg_trigger_depth() > 1 THEN RETURN NULL; END IF;

  v_task_id := COALESCE(NEW.task_id, OLD.task_id);

  SELECT user_id INTO v_primary_user
  FROM   public.task_assignments
  WHERE  task_id = v_task_id AND is_primary = TRUE
  LIMIT  1;

  UPDATE public.tasks
  SET    assigned_to = v_primary_user,
         updated_at  = NOW()
  WHERE  id = v_task_id;

  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_sync_assignment_to_task
  AFTER INSERT OR UPDATE OR DELETE ON public.task_assignments
  FOR EACH ROW EXECUTE FUNCTION public.sync_assignment_to_task();

-- ── 4. Trigger B: tasks.assigned_to UPDATE → task_assignments ────────────────
-- Backward compat: when legacy code (e.g. updateTask) writes assigned_to
-- directly on tasks, keep task_assignments in sync.

CREATE OR REPLACE FUNCTION public.sync_task_assigned_to()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF pg_trigger_depth() > 1 THEN RETURN NEW; END IF;
  IF NEW.assigned_to IS DISTINCT FROM OLD.assigned_to THEN
    IF OLD.assigned_to IS NOT NULL THEN
      DELETE FROM public.task_assignments
      WHERE  task_id = NEW.id
        AND  user_id = OLD.assigned_to
        AND  is_primary = TRUE;
    END IF;
    IF NEW.assigned_to IS NOT NULL THEN
      INSERT INTO public.task_assignments (task_id, user_id, assignment_role, is_primary)
      VALUES (NEW.id, NEW.assigned_to, 'lead', TRUE)
      ON CONFLICT (task_id, user_id) DO UPDATE
        SET is_primary = TRUE, assignment_role = 'lead';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_task_assigned_to
  AFTER UPDATE OF assigned_to ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.sync_task_assigned_to();

-- Trigger B (INSERT variant): trip creation service inserts tasks with
-- assigned_to set; this seeds the task_assignments row automatically.

CREATE OR REPLACE FUNCTION public.sync_task_assigned_to_on_insert()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF pg_trigger_depth() > 1 THEN RETURN NEW; END IF;
  IF NEW.assigned_to IS NOT NULL THEN
    INSERT INTO public.task_assignments (task_id, user_id, assignment_role, is_primary)
    VALUES (NEW.id, NEW.assigned_to, 'lead', TRUE)
    ON CONFLICT (task_id, user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_task_assigned_to_on_insert
  AFTER INSERT ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.sync_task_assigned_to_on_insert();

-- ── 5. Migrate existing data ──────────────────────────────────────────────────

INSERT INTO public.task_assignments (task_id, user_id, assignment_role, is_primary)
SELECT id, assigned_to, 'lead', TRUE
FROM   public.tasks
WHERE  assigned_to IS NOT NULL
ON CONFLICT (task_id, user_id) DO NOTHING;
