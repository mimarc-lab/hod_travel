-- =============================================================================
-- HOD Travel — 003_triggers.sql
-- Functions and triggers
-- Run after 001_schema.sql
-- =============================================================================

-- =============================================================================
-- HELPER: updated_at auto-stamp
-- =============================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Explicit per-table triggers (replaces the dynamic DO block — more readable
-- and easier to verify in migrations tooling).

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.profiles;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.teams;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.teams
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.team_members;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.team_members
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.trips;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.trips
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.board_groups;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.board_groups
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.suppliers;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.suppliers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.trip_days;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.trip_days
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.tasks;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.task_comments;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.task_comments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.itinerary_items;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.itinerary_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.cost_items;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.cost_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- AUTH: auto-create profile on sign-up
-- Fires after a new row is inserted in auth.users.
-- Inserts a matching row in public.profiles using the user's id, email,
-- and full_name from user_metadata (set at sign-up via signUp() options).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- BOARD GROUPS: auto-create default groups on trip insert
-- Creates the 6 standard board columns every time a new trip is saved.
-- These are inserted unconditionally — call this trigger only once per trip.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_default_board_groups()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.board_groups (trip_id, name, sort_order)
  VALUES
    (NEW.id, 'Pre-Planning',     0),
    (NEW.id, 'Accommodation',    1),
    (NEW.id, 'Experiences',      2),
    (NEW.id, 'Logistics',        3),
    (NEW.id, 'Finance',          4),
    (NEW.id, 'Client Delivery',  5);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_create_default_board_groups ON public.trips;
CREATE TRIGGER trg_create_default_board_groups
  AFTER INSERT ON public.trips
  FOR EACH ROW EXECUTE FUNCTION public.create_default_board_groups();

-- =============================================================================
-- TASKS: consolidated activity logging
-- Single AFTER UPDATE trigger handles all tracked field changes on tasks.
-- Consolidating into one function reduces trigger overhead: Postgres evaluates
-- one trigger per UPDATE row instead of four.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.log_task_changes()
RETURNS TRIGGER AS $$
BEGIN
  -- Status changed
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.task_activities (
      task_id, actor_id, activity_type, message, metadata
    ) VALUES (
      NEW.id,
      auth.uid(),
      'status_changed',
      'Status changed from "' || OLD.status || '" to "' || NEW.status || '"',
      jsonb_build_object('old_status', OLD.status, 'new_status', NEW.status)
    );
  END IF;

  -- Approval status changed
  IF OLD.approval_status IS DISTINCT FROM NEW.approval_status THEN
    INSERT INTO public.task_activities (
      task_id, actor_id, activity_type, message, metadata
    ) VALUES (
      NEW.id,
      auth.uid(),
      'approval_changed',
      'Approval changed from "' || OLD.approval_status || '" to "' || NEW.approval_status || '"',
      jsonb_build_object(
        'old_approval_status', OLD.approval_status,
        'new_approval_status', NEW.approval_status
      )
    );
  END IF;

  -- Assignee changed
  IF OLD.assigned_to IS DISTINCT FROM NEW.assigned_to THEN
    INSERT INTO public.task_activities (
      task_id, actor_id, activity_type, message, metadata
    ) VALUES (
      NEW.id,
      auth.uid(),
      'assigned_user_changed',
      CASE
        WHEN NEW.assigned_to IS NULL THEN 'Assignee removed'
        ELSE 'Task assigned to a new user'
      END,
      jsonb_build_object(
        'old_assigned_to', OLD.assigned_to,
        'new_assigned_to', NEW.assigned_to
      )
    );
  END IF;

  -- Supplier linked (only log when a supplier is newly set, not when cleared)
  IF OLD.supplier_id IS DISTINCT FROM NEW.supplier_id
     AND NEW.supplier_id IS NOT NULL THEN
    INSERT INTO public.task_activities (
      task_id, actor_id, activity_type, message, metadata
    ) VALUES (
      NEW.id,
      auth.uid(),
      'supplier_linked',
      'Supplier linked to task',
      jsonb_build_object(
        'old_supplier_id', OLD.supplier_id,
        'new_supplier_id', NEW.supplier_id
      )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_log_task_changes ON public.tasks;
CREATE TRIGGER trg_log_task_changes
  AFTER UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.log_task_changes();

-- =============================================================================
-- TASK COMMENTS: auto-log activity when a comment is added
-- =============================================================================

CREATE OR REPLACE FUNCTION public.log_comment_added()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.task_activities (
    task_id, actor_id, activity_type, message, metadata
  ) VALUES (
    NEW.task_id,
    NEW.author_id,
    'comment_added',
    'Comment added',
    jsonb_build_object('comment_id', NEW.id)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_log_comment_added ON public.task_comments;
CREATE TRIGGER trg_log_comment_added
  AFTER INSERT ON public.task_comments
  FOR EACH ROW EXECUTE FUNCTION public.log_comment_added();

-- =============================================================================
-- APPROVAL RECORDS: append a record whenever an entity's approval_status changes
-- Covers tasks, itinerary_items, and cost_items via a single shared function.
-- Each table gets its own trigger pointing at this function.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.append_approval_record()
RETURNS TRIGGER AS $$
DECLARE
  v_entity_type TEXT;
BEGIN
  IF OLD.approval_status IS DISTINCT FROM NEW.approval_status THEN
    v_entity_type := CASE TG_TABLE_NAME
      WHEN 'tasks'           THEN 'task'
      WHEN 'itinerary_items' THEN 'itinerary_item'
      WHEN 'cost_items'      THEN 'cost_item'
      ELSE TG_TABLE_NAME
    END;

    INSERT INTO public.approval_records (
      team_id, entity_type, entity_id, status, actor_id
    ) VALUES (
      NEW.team_id,
      v_entity_type,
      NEW.id,
      NEW.approval_status,
      auth.uid()
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_append_approval_record ON public.tasks;
CREATE TRIGGER trg_append_approval_record
  AFTER UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.append_approval_record();

DROP TRIGGER IF EXISTS trg_append_approval_record ON public.itinerary_items;
CREATE TRIGGER trg_append_approval_record
  AFTER UPDATE ON public.itinerary_items
  FOR EACH ROW EXECUTE FUNCTION public.append_approval_record();

DROP TRIGGER IF EXISTS trg_append_approval_record ON public.cost_items;
CREATE TRIGGER trg_append_approval_record
  AFTER UPDATE ON public.cost_items
  FOR EACH ROW EXECUTE FUNCTION public.append_approval_record();
