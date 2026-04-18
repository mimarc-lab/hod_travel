-- =============================================================================
-- HOD Travel — 002_indexes.sql
-- Performance indexes
-- Run after 001_schema.sql
-- =============================================================================

-- =============================================================================
-- TEAM MEMBERS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_team_members_team_id  ON public.team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user_id  ON public.team_members(user_id);
CREATE INDEX IF NOT EXISTS idx_team_members_active   ON public.team_members(team_id, is_active);

-- =============================================================================
-- TRIPS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_trips_team_id      ON public.trips(team_id);
CREATE INDEX IF NOT EXISTS idx_trips_trip_lead_id ON public.trips(trip_lead_id);
CREATE INDEX IF NOT EXISTS idx_trips_team_status  ON public.trips(team_id, status);
-- Note: standalone (status) index removed — never queried without team_id

-- =============================================================================
-- TRIP DESTINATIONS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_trip_destinations_trip_id ON public.trip_destinations(trip_id);

-- =============================================================================
-- BOARD GROUPS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_board_groups_trip_id ON public.board_groups(trip_id);

-- =============================================================================
-- SUPPLIERS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_suppliers_team_id   ON public.suppliers(team_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_category  ON public.suppliers(category);
CREATE INDEX IF NOT EXISTS idx_suppliers_city      ON public.suppliers(city);
CREATE INDEX IF NOT EXISTS idx_suppliers_preferred ON public.suppliers(team_id, preferred);

-- =============================================================================
-- SUPPLIER TAG LINKS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_supplier_tag_links_tag_id ON public.supplier_tag_links(tag_id);
-- Note: (supplier_id, tag_id) primary key already covers supplier_id lookups

-- =============================================================================
-- SUPPLIER ENRICHMENTS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_supplier_enrichments_supplier_id ON public.supplier_enrichments(supplier_id);
CREATE INDEX IF NOT EXISTS idx_supplier_enrichments_team_id     ON public.supplier_enrichments(team_id);
CREATE INDEX IF NOT EXISTS idx_supplier_enrichments_action      ON public.supplier_enrichments(team_id, action_taken);

-- =============================================================================
-- TRIP DAYS
-- =============================================================================

-- trip_days(trip_id): UNIQUE (trip_id, day_number) already provides a covering index — no extra index needed
CREATE INDEX IF NOT EXISTS idx_trip_days_team_id ON public.trip_days(team_id);

-- =============================================================================
-- TASKS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_tasks_trip_id      ON public.tasks(trip_id);
CREATE INDEX IF NOT EXISTS idx_tasks_team_id      ON public.tasks(team_id);
CREATE INDEX IF NOT EXISTS idx_tasks_group_id     ON public.tasks(board_group_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to  ON public.tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_supplier_id  ON public.tasks(supplier_id);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date     ON public.tasks(due_date)
  WHERE due_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_status       ON public.tasks(team_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_approval     ON public.tasks(team_id, approval_status);

-- =============================================================================
-- TASK COMMENTS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_task_comments_task_id ON public.task_comments(task_id);

-- =============================================================================
-- TASK ACTIVITIES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_task_activities_task_id ON public.task_activities(task_id);
CREATE INDEX IF NOT EXISTS idx_task_activities_type    ON public.task_activities(task_id, activity_type);

-- =============================================================================
-- ITINERARY ITEMS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_itinerary_items_trip_day_id ON public.itinerary_items(trip_day_id);
CREATE INDEX IF NOT EXISTS idx_itinerary_items_team_id     ON public.itinerary_items(team_id);
CREATE INDEX IF NOT EXISTS idx_itinerary_items_supplier_id ON public.itinerary_items(supplier_id)
  WHERE supplier_id IS NOT NULL;

-- =============================================================================
-- COST ITEMS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_cost_items_trip_id        ON public.cost_items(trip_id);
CREATE INDEX IF NOT EXISTS idx_cost_items_team_id        ON public.cost_items(team_id);
CREATE INDEX IF NOT EXISTS idx_cost_items_supplier_id    ON public.cost_items(supplier_id)
  WHERE supplier_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_cost_items_payment_status ON public.cost_items(trip_id, payment_status);
CREATE INDEX IF NOT EXISTS idx_cost_items_approval       ON public.cost_items(team_id, approval_status);

-- =============================================================================
-- NOTIFICATIONS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread  ON public.notifications(user_id, is_read)
  WHERE is_read = FALSE;

-- =============================================================================
-- ATTACHMENTS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_attachments_team_id    ON public.attachments(team_id);
CREATE INDEX IF NOT EXISTS idx_attachments_related_id ON public.attachments(related_table, related_id);

-- =============================================================================
-- APPROVAL RECORDS
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_approval_records_team_id   ON public.approval_records(team_id);
CREATE INDEX IF NOT EXISTS idx_approval_records_entity_id ON public.approval_records(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_approval_records_status    ON public.approval_records(team_id, status);
