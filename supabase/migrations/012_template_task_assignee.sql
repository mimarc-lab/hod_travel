-- =============================================================================
-- 012_template_task_assignee.sql
-- Adds an optional default assignee to each trip template task so that when
-- a template is applied to a new trip, tasks are pre-assigned automatically.
-- =============================================================================

ALTER TABLE public.trip_template_tasks
  ADD COLUMN IF NOT EXISTS default_assignee_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
