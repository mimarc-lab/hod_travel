-- 016_subtask_templates_per_task.sql
-- Link subtask templates to a specific trip_template_task instead of a group.

ALTER TABLE public.subtask_templates
  ADD COLUMN IF NOT EXISTS trip_template_task_id UUID
    REFERENCES public.trip_template_tasks(id) ON DELETE CASCADE;

-- task_type is kept for backward-compat with existing group-level seed data.
-- New per-task templates use trip_template_task_id; task_type becomes nullable.
ALTER TABLE public.subtask_templates
  ALTER COLUMN task_type DROP NOT NULL;

-- Index for fast lookups by template task
CREATE INDEX IF NOT EXISTS idx_subtask_templates_template_task
  ON public.subtask_templates(trip_template_task_id);
