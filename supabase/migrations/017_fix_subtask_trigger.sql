-- Migration 017: Optimise subtask count trigger
--
-- Problem: trg_sync_subtask_counts fires on every subtask UPDATE (including
-- title-only edits). This propagates a tasks table UPDATE which fires the
-- Supabase Realtime watchGroupsForTrip subscription, causing the entire board
-- to re-render and Flutter to destroy/recreate TaskRow/BoardGroupWidget state.
--
-- Fix: restrict the UPDATE firing condition to rows where is_completed actually
-- changed. INSERT and DELETE still always fire (they always affect counts).

CREATE OR REPLACE FUNCTION public.sync_subtask_counts()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_task_id UUID;
BEGIN
  v_task_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.parent_task_id ELSE NEW.parent_task_id END;
  UPDATE public.tasks
  SET
    subtask_count           = (SELECT COUNT(*)              FROM public.subtasks WHERE parent_task_id = v_task_id),
    completed_subtask_count = (SELECT COUNT(*) FROM public.subtasks WHERE parent_task_id = v_task_id AND is_completed = TRUE)
  WHERE id = v_task_id;
  RETURN NULL;
END;
$$;

-- Drop old trigger (fires on any UPDATE column)
DROP TRIGGER IF EXISTS trg_sync_subtask_counts ON public.subtasks;

-- INSERT / DELETE: always recalculate counts
CREATE TRIGGER trg_sync_subtask_counts_insert_delete
  AFTER INSERT OR DELETE ON public.subtasks
  FOR EACH ROW EXECUTE FUNCTION public.sync_subtask_counts();

-- UPDATE: only recalculate when is_completed changes
CREATE TRIGGER trg_sync_subtask_counts_update
  AFTER UPDATE OF is_completed ON public.subtasks
  FOR EACH ROW EXECUTE FUNCTION public.sync_subtask_counts();
