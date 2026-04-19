-- =============================================================================
-- 010_smart_scheduling.sql
-- Adds scheduling metadata columns to support the backward planning engine.
-- =============================================================================

-- ── trip_template_tasks ──────────────────────────────────────────────────────
ALTER TABLE public.trip_template_tasks
  ADD COLUMN IF NOT EXISTS estimated_duration_days  INT  NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS scheduling_mode          TEXT NOT NULL DEFAULT 'backward_from_deadline',
  ADD COLUMN IF NOT EXISTS dependency_task_ids      TEXT[]        DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS buffer_days              INT  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS category_priority        INT  NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS earliest_start_offset_days INT,
  ADD COLUMN IF NOT EXISTS latest_finish_offset_days  INT;

-- ── tasks ────────────────────────────────────────────────────────────────────
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS estimated_duration_days INT;

-- ── trips ────────────────────────────────────────────────────────────────────
ALTER TABLE public.trips
  ADD COLUMN IF NOT EXISTS planning_buffer_days  INT  NOT NULL DEFAULT 7,
  ADD COLUMN IF NOT EXISTS planning_complete_by  DATE;
