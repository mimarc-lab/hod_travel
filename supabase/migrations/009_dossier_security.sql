-- =============================================================================
-- HOD Travel — 009_dossier_security.sql
-- Dossier Security Layer: RBAC + user overrides + audit logging
--
-- Layers:
--   1. role_permission_defaults  — what each role can do by default
--   2. team_member_permissions   — per-user overrides that take precedence
--   3. get_effective_permission  — resolver used inside RLS policies
--   4. resolve_dossier_permissions — RPC for Flutter client (one round-trip)
--   5. audit_logs                — write-event capture via trigger
--   6. client_sensitive_notes    — high-clearance content, separate table
--   7. RLS policies              — replace simple team-check with permission-check
-- =============================================================================

-- =============================================================================
-- 1. ROLE PERMISSION DEFAULTS
-- Static table — one row per (role, permission_key).
-- Admins can UPDATE these values via the app; no INSERT/DELETE of roles needed.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.role_permission_defaults (
  role             TEXT    NOT NULL
                           CHECK (role IN ('admin','trip_lead','staff','finance')),
  permission_key   TEXT    NOT NULL,
  permission_value BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (role, permission_key)
);

-- Seed defaults — safe to re-run (ON CONFLICT DO UPDATE)
INSERT INTO public.role_permission_defaults (role, permission_key, permission_value) VALUES
  -- admin: full access
  ('admin',     'can_view_dossier',          TRUE),
  ('admin',     'can_edit_dossier',          TRUE),
  ('admin',     'can_view_sensitive_notes',  TRUE),

  -- trip_lead: view + edit, no sensitive by default
  ('trip_lead', 'can_view_dossier',          TRUE),
  ('trip_lead', 'can_edit_dossier',          TRUE),
  ('trip_lead', 'can_view_sensitive_notes',  FALSE),

  -- staff: no dossier access by default
  ('staff',     'can_view_dossier',          FALSE),
  ('staff',     'can_edit_dossier',          FALSE),
  ('staff',     'can_view_sensitive_notes',  FALSE),

  -- finance: no dossier access
  ('finance',   'can_view_dossier',          FALSE),
  ('finance',   'can_edit_dossier',          FALSE),
  ('finance',   'can_view_sensitive_notes',  FALSE)

ON CONFLICT (role, permission_key) DO UPDATE
  SET permission_value = EXCLUDED.permission_value;

-- =============================================================================
-- 2. TEAM MEMBER PERMISSION OVERRIDES
-- Per-user overrides. Takes precedence over role defaults.
-- Only admins can write; anyone in the team can read their own row.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.team_member_permissions (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID        NOT NULL REFERENCES auth.users(id)    ON DELETE CASCADE,
  team_id          UUID        NOT NULL REFERENCES public.teams(id)  ON DELETE CASCADE,
  permission_key   TEXT        NOT NULL,
  permission_value BOOLEAN     NOT NULL,
  granted_by       UUID        REFERENCES auth.users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, team_id, permission_key)
);

CREATE INDEX IF NOT EXISTS idx_tmp_user_team
  ON public.team_member_permissions (user_id, team_id);

-- =============================================================================
-- 3. CLIENT SENSITIVE NOTES
-- High-clearance table. Requires can_view_sensitive_notes to SELECT.
-- team_id copied from parent dossier for direct RLS evaluation.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.client_sensitive_notes (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  dossier_id  UUID        NOT NULL REFERENCES public.client_dossiers(id) ON DELETE CASCADE,
  team_id     UUID        NOT NULL REFERENCES public.teams(id),
  content     TEXT        NOT NULL,
  note_type   TEXT        NOT NULL DEFAULT 'general'
                          CHECK (note_type IN ('general','medical','security','vip')),
  created_by  UUID        REFERENCES auth.users(id),
  updated_by  UUID        REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_csn_dossier ON public.client_sensitive_notes (dossier_id);

-- =============================================================================
-- 4. AUDIT LOGS
-- Append-only. Write events come from triggers. View events from Flutter app.
-- team_id stored as TEXT to accommodate tables that store it as text.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        NOT NULL,
  team_id       TEXT        NOT NULL,
  action_type   TEXT        NOT NULL
                            CHECK (action_type IN ('view','create','update','delete')),
  entity_type   TEXT        NOT NULL,
  entity_id     TEXT        NOT NULL,
  metadata_json JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_team_entity
  ON public.audit_logs (team_id, entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_user
  ON public.audit_logs (user_id, created_at DESC);

-- =============================================================================
-- 5. EFFECTIVE PERMISSION RESOLVER FUNCTION
-- Used inside RLS policies. SECURITY DEFINER so it can read permission tables
-- regardless of the calling user's RLS context.
-- Two overloads: UUID (native) and TEXT (for tables with text team_id column).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_effective_permission(
  p_user_id        UUID,
  p_team_id        UUID,
  p_permission_key TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_role           TEXT;
  v_override_value BOOLEAN;
  v_default_value  BOOLEAN;
BEGIN
  -- Step 1: confirm active team membership and get role
  SELECT role INTO v_role
  FROM   public.team_members
  WHERE  user_id  = p_user_id
    AND  team_id  = p_team_id
    AND  is_active = TRUE
  LIMIT 1;

  IF v_role IS NULL THEN
    RETURN FALSE;  -- not a member of this team
  END IF;

  -- Step 2: check for a user-specific override
  SELECT permission_value INTO v_override_value
  FROM   public.team_member_permissions
  WHERE  user_id        = p_user_id
    AND  team_id        = p_team_id
    AND  permission_key = p_permission_key;

  IF FOUND THEN
    RETURN v_override_value;
  END IF;

  -- Step 3: fall back to role default
  SELECT permission_value INTO v_default_value
  FROM   public.role_permission_defaults
  WHERE  role           = v_role
    AND  permission_key = p_permission_key;

  RETURN COALESCE(v_default_value, FALSE);
END;
$$;

-- TEXT overload — for tables where team_id column is type TEXT
CREATE OR REPLACE FUNCTION public.get_effective_permission(
  p_user_id        UUID,
  p_team_id        TEXT,
  p_permission_key TEXT
)
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT public.get_effective_permission(p_user_id, p_team_id::uuid, p_permission_key);
$$;

-- =============================================================================
-- 6. RESOLVE DOSSIER PERMISSIONS RPC
-- Called by Flutter via .rpc('resolve_dossier_permissions').
-- Returns all three permission keys in one round-trip.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.resolve_dossier_permissions(
  p_team_id TEXT DEFAULT NULL
)
RETURNS TABLE (
  permission_key   TEXT,
  permission_value BOOLEAN,
  source           TEXT
)
LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_user_id  UUID := auth.uid();
  v_team_uuid UUID;
  v_role     TEXT;
BEGIN
  -- Resolve team
  IF p_team_id IS NOT NULL THEN
    v_team_uuid := p_team_id::uuid;
  ELSE
    SELECT team_id INTO v_team_uuid
    FROM   public.team_members
    WHERE  user_id   = v_user_id
      AND  is_active = TRUE
    ORDER BY created_at
    LIMIT 1;
  END IF;

  IF v_team_uuid IS NULL THEN RETURN; END IF;

  -- Get role
  SELECT role INTO v_role
  FROM   public.team_members
  WHERE  user_id   = v_user_id
    AND  team_id   = v_team_uuid
    AND  is_active = TRUE;

  IF v_role IS NULL THEN RETURN; END IF;

  -- Return merged: override takes precedence
  RETURN QUERY
  WITH role_defaults AS (
    SELECT rd.permission_key, rd.permission_value
    FROM   public.role_permission_defaults rd
    WHERE  rd.role = v_role
  ),
  overrides AS (
    SELECT tmp.permission_key, tmp.permission_value
    FROM   public.team_member_permissions tmp
    WHERE  tmp.user_id  = v_user_id
      AND  tmp.team_id  = v_team_uuid
  )
  SELECT
    d.permission_key::TEXT,
    COALESCE(o.permission_value, d.permission_value) AS permission_value,
    CASE WHEN o.permission_key IS NOT NULL THEN 'override'::TEXT
         ELSE 'role_default'::TEXT END AS source
  FROM role_defaults d
  LEFT JOIN overrides o USING (permission_key);
END;
$$;

-- =============================================================================
-- 7. AUDIT TRIGGER
-- Fires on INSERT, UPDATE, DELETE for client_dossiers and client_sensitive_notes.
-- Captures which fields changed on UPDATE (keys only, not values, for privacy).
-- SELECT-level events are logged by the Flutter app via AuditLogService.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_audit_dossier_write()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_entity_id TEXT;
  v_team_id   TEXT;
  v_meta      JSONB := '{}'::jsonb;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_entity_id := OLD.id::TEXT;
    v_team_id   := OLD.team_id::TEXT;
  ELSE
    v_entity_id := NEW.id::TEXT;
    v_team_id   := NEW.team_id::TEXT;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    SELECT jsonb_build_object('changed_fields', jsonb_agg(DISTINCT key ORDER BY key))
    INTO   v_meta
    FROM (
      SELECT n.key
      FROM   jsonb_each(to_jsonb(NEW)) n
      JOIN   jsonb_each(to_jsonb(OLD)) o USING (key)
      WHERE  n.value IS DISTINCT FROM o.value
        AND  n.key NOT IN ('updated_at')  -- skip noise
    ) changed;
  END IF;

  INSERT INTO public.audit_logs
    (user_id, team_id, action_type, entity_type, entity_id, metadata_json)
  VALUES
    (
      auth.uid(),
      v_team_id,
      LOWER(TG_OP),
      TG_TABLE_NAME,
      v_entity_id,
      v_meta
    );

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_dossier ON public.client_dossiers;
CREATE TRIGGER trg_audit_dossier
  AFTER INSERT OR UPDATE OR DELETE ON public.client_dossiers
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_dossier_write();

DROP TRIGGER IF EXISTS trg_audit_sensitive_notes ON public.client_sensitive_notes;
CREATE TRIGGER trg_audit_sensitive_notes
  AFTER INSERT OR UPDATE OR DELETE ON public.client_sensitive_notes
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_dossier_write();

-- =============================================================================
-- 8. ROW LEVEL SECURITY — ENABLE ON NEW TABLES
-- =============================================================================

ALTER TABLE public.role_permission_defaults   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_member_permissions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_sensitive_notes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs                  ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 9. RLS POLICIES — PERMISSION TABLES
-- =============================================================================

-- role_permission_defaults: all authenticated users can read (needed by RPC).
-- Only admins may update values.
CREATE POLICY "rpd: authenticated read"
  ON public.role_permission_defaults FOR SELECT
  TO authenticated USING (TRUE);

CREATE POLICY "rpd: admin write"
  ON public.role_permission_defaults FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members
      WHERE  user_id   = auth.uid()
        AND  role      = 'admin'
        AND  is_active = TRUE
    )
  )
  WITH CHECK (TRUE);

-- team_member_permissions: users see own row; admins see whole team.
CREATE POLICY "tmp: read own or team admin"
  ON public.team_member_permissions FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.team_members tm
      WHERE  tm.user_id   = auth.uid()
        AND  tm.team_id   = team_member_permissions.team_id
        AND  tm.role      = 'admin'
        AND  tm.is_active = TRUE
    )
  );

CREATE POLICY "tmp: admin write"
  ON public.team_member_permissions FOR ALL
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.team_members tm
      WHERE  tm.user_id   = auth.uid()
        AND  tm.team_id   = team_member_permissions.team_id
        AND  tm.role      = 'admin'
        AND  tm.is_active = TRUE
    )
  );

-- =============================================================================
-- 10. RLS POLICIES — DOSSIER TABLES (replace simple team-check policies)
-- =============================================================================

-- ── client_dossiers ───────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "client_dossiers: team full access" ON public.client_dossiers;

CREATE POLICY "client_dossiers: select"
  ON public.client_dossiers FOR SELECT
  TO authenticated
  USING (get_effective_permission(auth.uid(), team_id, 'can_view_dossier'));

CREATE POLICY "client_dossiers: insert"
  ON public.client_dossiers FOR INSERT
  TO authenticated
  WITH CHECK (get_effective_permission(auth.uid(), team_id, 'can_edit_dossier'));

CREATE POLICY "client_dossiers: update"
  ON public.client_dossiers FOR UPDATE
  TO authenticated
  USING     (get_effective_permission(auth.uid(), team_id, 'can_edit_dossier'))
  WITH CHECK(get_effective_permission(auth.uid(), team_id, 'can_edit_dossier'));

CREATE POLICY "client_dossiers: delete"
  ON public.client_dossiers FOR DELETE
  TO authenticated
  USING (get_effective_permission(auth.uid(), team_id, 'can_edit_dossier'));

-- ── client_travelers (derives access via parent dossier) ──────────────────────
DROP POLICY IF EXISTS "client_travelers: team full access" ON public.client_travelers;

CREATE POLICY "client_travelers: select"
  ON public.client_travelers FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.client_dossiers d
      WHERE  d.id = dossier_id
        AND  get_effective_permission(auth.uid(), d.team_id, 'can_view_dossier')
    )
  );

CREATE POLICY "client_travelers: insert"
  ON public.client_travelers FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.client_dossiers d
      WHERE  d.id = dossier_id
        AND  get_effective_permission(auth.uid(), d.team_id, 'can_edit_dossier')
    )
  );

CREATE POLICY "client_travelers: update"
  ON public.client_travelers FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.client_dossiers d
      WHERE  d.id = dossier_id
        AND  get_effective_permission(auth.uid(), d.team_id, 'can_edit_dossier')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.client_dossiers d
      WHERE  d.id = dossier_id
        AND  get_effective_permission(auth.uid(), d.team_id, 'can_edit_dossier')
    )
  );

CREATE POLICY "client_travelers: delete"
  ON public.client_travelers FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.client_dossiers d
      WHERE  d.id = dossier_id
        AND  get_effective_permission(auth.uid(), d.team_id, 'can_edit_dossier')
    )
  );

-- ── client_questionnaire_responses ────────────────────────────────────────────
DROP POLICY IF EXISTS "client_questionnaire_responses: team full access"
  ON public.client_questionnaire_responses;

CREATE POLICY "client_questionnaire_responses: select"
  ON public.client_questionnaire_responses FOR SELECT
  TO authenticated
  USING (get_effective_permission(auth.uid(), team_id, 'can_view_dossier'));

CREATE POLICY "client_questionnaire_responses: insert"
  ON public.client_questionnaire_responses FOR INSERT
  TO authenticated
  WITH CHECK (get_effective_permission(auth.uid(), team_id, 'can_edit_dossier'));

CREATE POLICY "client_questionnaire_responses: update"
  ON public.client_questionnaire_responses FOR UPDATE
  TO authenticated
  USING     (get_effective_permission(auth.uid(), team_id, 'can_edit_dossier'))
  WITH CHECK(get_effective_permission(auth.uid(), team_id, 'can_edit_dossier'));

-- ── client_sensitive_notes ────────────────────────────────────────────────────
CREATE POLICY "client_sensitive_notes: select"
  ON public.client_sensitive_notes FOR SELECT
  TO authenticated
  USING (get_effective_permission(auth.uid(), team_id, 'can_view_sensitive_notes'));

CREATE POLICY "client_sensitive_notes: insert"
  ON public.client_sensitive_notes FOR INSERT
  TO authenticated
  WITH CHECK (
    get_effective_permission(auth.uid(), team_id, 'can_edit_dossier')
    AND get_effective_permission(auth.uid(), team_id, 'can_view_sensitive_notes')
  );

CREATE POLICY "client_sensitive_notes: update"
  ON public.client_sensitive_notes FOR UPDATE
  TO authenticated
  USING (
    get_effective_permission(auth.uid(), team_id, 'can_edit_dossier')
    AND get_effective_permission(auth.uid(), team_id, 'can_view_sensitive_notes')
  )
  WITH CHECK (
    get_effective_permission(auth.uid(), team_id, 'can_edit_dossier')
    AND get_effective_permission(auth.uid(), team_id, 'can_view_sensitive_notes')
  );

CREATE POLICY "client_sensitive_notes: delete"
  ON public.client_sensitive_notes FOR DELETE
  TO authenticated
  USING (get_effective_permission(auth.uid(), team_id, 'can_edit_dossier'));

-- =============================================================================
-- 11. RLS POLICIES — AUDIT LOGS
-- Team members can read their team's logs. Inserts only for own user_id.
-- Trigger inserts bypass RLS via SECURITY DEFINER.
-- =============================================================================

CREATE POLICY "audit_logs: team read"
  ON public.audit_logs FOR SELECT
  TO authenticated
  USING (is_team_member(team_id::uuid));

CREATE POLICY "audit_logs: self insert"
  ON public.audit_logs FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- No UPDATE or DELETE on audit_logs — append-only.
