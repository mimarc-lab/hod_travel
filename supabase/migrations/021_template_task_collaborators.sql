-- =============================================================================
-- 021_template_task_collaborators.sql
-- Adds default_collaborator_ids (UUID array) to trip_template_tasks so that
-- template tasks can pre-assign both a lead and multiple collaborators.
-- =============================================================================

ALTER TABLE public.trip_template_tasks
  ADD COLUMN IF NOT EXISTS default_collaborator_ids UUID[] NOT NULL DEFAULT '{}';
