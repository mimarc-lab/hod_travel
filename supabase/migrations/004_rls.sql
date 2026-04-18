-- =============================================================================
-- HOD Travel — 004_rls.sql
-- Row Level Security — Stage 1: team-scoped access
-- Run after 001_schema.sql
--
-- STRATEGY
-- ─────────
-- Every major table carries a team_id column. The core rule is:
--
--   "A user can access a row if they are an active member of its team."
--
-- This is evaluated via is_team_member(team_id), a SECURITY DEFINER
-- function that checks public.team_members. Keeping the check in a
-- function means policies stay readable and the logic lives in one place.
--
-- Tables that don't carry team_id directly (trip_destinations,
-- board_groups, task_comments, task_activities, supplier_tag_links)
-- derive access by joining back to their parent.
--
-- Notifications and profiles are special-cased (self-scoped).
--
-- Stage 2 (future): add role-aware policies for finance/approval fields.
-- =============================================================================

-- =============================================================================
-- HELPER: team membership check
-- Returns TRUE if the calling auth user is an active member of p_team_id.
-- SECURITY DEFINER so it can read team_members regardless of that table's RLS.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.is_team_member(p_team_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1
    FROM   public.team_members
    WHERE  team_id   = p_team_id
      AND  user_id   = auth.uid()
      AND  is_active = TRUE
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- =============================================================================
-- ENABLE RLS ON ALL TABLES
-- =============================================================================

ALTER TABLE public.profiles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_destinations    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.board_groups         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_tags        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_tag_links   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_enrichments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_days            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_comments        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_activities      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.itinerary_items      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cost_items           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attachments          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approval_records     ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- PROFILES
-- Any authenticated user can read all profiles (needed for assignee dropdowns).
-- Users can only insert/update their own row.
-- =============================================================================

CREATE POLICY "profiles: authenticated read all"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (TRUE);

CREATE POLICY "profiles: own insert"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY "profiles: own update"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid());

-- =============================================================================
-- TEAMS
-- Members can read their own team.
-- Any authenticated user can create a team (they become its first member in app logic).
-- Only team members can update team details.
-- =============================================================================

CREATE POLICY "teams: member read"
  ON public.teams FOR SELECT
  TO authenticated
  USING (is_team_member(id));

CREATE POLICY "teams: authenticated insert"
  ON public.teams FOR INSERT
  TO authenticated
  WITH CHECK (TRUE);

CREATE POLICY "teams: member update"
  ON public.teams FOR UPDATE
  TO authenticated
  USING (is_team_member(id))
  WITH CHECK (is_team_member(id));

-- =============================================================================
-- TEAM MEMBERS
-- Members can read, add, and update members within their own team.
-- Delete is restricted to admins — enforced at app layer, not DB layer yet.
-- =============================================================================

CREATE POLICY "team_members: member read"
  ON public.team_members FOR SELECT
  TO authenticated
  USING (is_team_member(team_id));

-- INSERT allows:
--   (a) a user adding themselves to a team they were invited to, OR
--   (b) an existing team member adding others.
-- Without (a), a brand-new team has no members and no one can join — chicken-and-egg.
CREATE POLICY "team_members: member insert"
  ON public.team_members FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()          -- user is adding themselves
    OR is_team_member(team_id)    -- or an existing member is adding someone
  );

CREATE POLICY "team_members: member update"
  ON public.team_members FOR UPDATE
  TO authenticated
  USING (is_team_member(team_id))
  WITH CHECK (is_team_member(team_id));

CREATE POLICY "team_members: member delete"
  ON public.team_members FOR DELETE
  TO authenticated
  USING (is_team_member(team_id));

-- =============================================================================
-- TRIPS
-- Full access for team members. team_id is on the row directly.
-- =============================================================================

CREATE POLICY "trips: team full access"
  ON public.trips FOR ALL
  TO authenticated
  USING  (is_team_member(team_id))
  WITH CHECK (is_team_member(team_id));

-- =============================================================================
-- TRIP DESTINATIONS
-- No team_id on this table — derive access via parent trip.
-- =============================================================================

CREATE POLICY "trip_destinations: team full access"
  ON public.trip_destinations FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.trips t
      WHERE  t.id = trip_id
        AND  is_team_member(t.team_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.trips t
      WHERE  t.id = trip_id
        AND  is_team_member(t.team_id)
    )
  );

-- =============================================================================
-- BOARD GROUPS
-- Derive access via parent trip.
-- =============================================================================

CREATE POLICY "board_groups: team full access"
  ON public.board_groups FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.trips t
      WHERE  t.id = trip_id
        AND  is_team_member(t.team_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.trips t
      WHERE  t.id = trip_id
        AND  is_team_member(t.team_id)
    )
  );

-- =============================================================================
-- SUPPLIERS
-- team_id is on the row. Full access for all team members.
-- =============================================================================

CREATE POLICY "suppliers: team full access"
  ON public.suppliers FOR ALL
  TO authenticated
  USING  (is_team_member(team_id))
  WITH CHECK (is_team_member(team_id));

-- =============================================================================
-- SUPPLIER TAGS
-- =============================================================================

CREATE POLICY "supplier_tags: team full access"
  ON public.supplier_tags FOR ALL
  TO authenticated
  USING  (is_team_member(team_id))
  WITH CHECK (is_team_member(team_id));

-- =============================================================================
-- SUPPLIER TAG LINKS
-- Derive access via parent supplier.
-- =============================================================================

CREATE POLICY "supplier_tag_links: team full access"
  ON public.supplier_tag_links FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.suppliers s
      WHERE  s.id = supplier_id
        AND  is_team_member(s.team_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.suppliers s
      WHERE  s.id = supplier_id
        AND  is_team_member(s.team_id)
    )
  );

-- =============================================================================
-- SUPPLIER ENRICHMENTS
-- team_id is on the row.
-- =============================================================================

CREATE POLICY "supplier_enrichments: team full access"
  ON public.supplier_enrichments FOR ALL
  TO authenticated
  USING  (is_team_member(team_id))
  WITH CHECK (is_team_member(team_id));

-- =============================================================================
-- TRIP DAYS
-- team_id is on the row.
-- =============================================================================

CREATE POLICY "trip_days: team full access"
  ON public.trip_days FOR ALL
  TO authenticated
  USING  (is_team_member(team_id))
  WITH CHECK (is_team_member(team_id));

-- =============================================================================
-- TASKS
-- team_id is on the row.
-- =============================================================================

CREATE POLICY "tasks: team full access"
  ON public.tasks FOR ALL
  TO authenticated
  USING  (is_team_member(team_id))
  WITH CHECK (is_team_member(team_id));

-- =============================================================================
-- TASK COMMENTS
-- Derive access via parent task (which carries team_id).
-- =============================================================================

CREATE POLICY "task_comments: team full access"
  ON public.task_comments FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.tasks tk
      WHERE  tk.id = task_id
        AND  is_team_member(tk.team_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.tasks tk
      WHERE  tk.id = task_id
        AND  is_team_member(tk.team_id)
    )
  );

-- =============================================================================
-- TASK ACTIVITIES
-- Read-only for team members (app logic writes via SECURITY DEFINER triggers).
-- Direct inserts allowed so app code can also write manual activity entries.
-- =============================================================================

CREATE POLICY "task_activities: team read"
  ON public.task_activities FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.tasks tk
      WHERE  tk.id = task_id
        AND  is_team_member(tk.team_id)
    )
  );

CREATE POLICY "task_activities: team insert"
  ON public.task_activities FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.tasks tk
      WHERE  tk.id = task_id
        AND  is_team_member(tk.team_id)
    )
  );

-- No UPDATE or DELETE on task_activities — it is an append-only audit log.

-- =============================================================================
-- ITINERARY ITEMS
-- team_id is on the row.
-- =============================================================================

CREATE POLICY "itinerary_items: team full access"
  ON public.itinerary_items FOR ALL
  TO authenticated
  USING  (is_team_member(team_id))
  WITH CHECK (is_team_member(team_id));

-- =============================================================================
-- COST ITEMS
-- team_id is on the row.
-- =============================================================================

CREATE POLICY "cost_items: team full access"
  ON public.cost_items FOR ALL
  TO authenticated
  USING  (is_team_member(team_id))
  WITH CHECK (is_team_member(team_id));

-- =============================================================================
-- NOTIFICATIONS
-- Users see and update only their own notifications.
-- Any team member can insert a notification for another user (e.g. system events).
-- =============================================================================

CREATE POLICY "notifications: own read"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "notifications: own update (mark read)"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "notifications: team insert"
  ON public.notifications FOR INSERT
  TO authenticated
  WITH CHECK (is_team_member(team_id));

-- =============================================================================
-- ATTACHMENTS
-- team_id is on the row.
-- =============================================================================

CREATE POLICY "attachments: team full access"
  ON public.attachments FOR ALL
  TO authenticated
  USING  (is_team_member(team_id))
  WITH CHECK (is_team_member(team_id));

-- =============================================================================
-- APPROVAL RECORDS
-- team_id is on the row. Append-only audit trail.
-- No UPDATE or DELETE — same as task_activities.
-- =============================================================================

CREATE POLICY "approval_records: team read"
  ON public.approval_records FOR SELECT
  TO authenticated
  USING (is_team_member(team_id));

CREATE POLICY "approval_records: team insert"
  ON public.approval_records FOR INSERT
  TO authenticated
  WITH CHECK (is_team_member(team_id));

-- No UPDATE or DELETE on approval_records.

-- =============================================================================
-- STAGE 2 PLACEHOLDERS (uncomment and expand when ready)
-- =============================================================================

-- Finance-only cost item update
-- CREATE POLICY "cost_items: finance update"
--   ON public.cost_items FOR UPDATE
--   TO authenticated
--   USING (
--     is_team_member(team_id) AND
--     EXISTS (
--       SELECT 1 FROM public.team_members tm
--       WHERE  tm.team_id = cost_items.team_id
--         AND  tm.user_id = auth.uid()
--         AND  tm.role IN ('admin','finance')
--     )
--   );

-- Trip-lead-only trip update
-- CREATE POLICY "trips: trip_lead update"
--   ON public.trips FOR UPDATE
--   TO authenticated
--   USING (
--     trip_lead_id = auth.uid() OR
--     EXISTS (
--       SELECT 1 FROM public.team_members tm
--       WHERE  tm.team_id = trips.team_id
--         AND  tm.user_id = auth.uid()
--         AND  tm.role = 'admin'
--     )
--   );
