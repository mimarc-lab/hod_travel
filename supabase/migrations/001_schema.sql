-- =============================================================================
-- HOD Travel — 001_schema.sql
-- Core table definitions
-- Run in Supabase: Dashboard → SQL Editor → New query
-- =============================================================================

-- gen_random_uuid() is built into PostgreSQL 13+ (used by Supabase).
-- No extension required.

-- =============================================================================
-- PROFILES
-- Lightweight identity table — mirrors auth.users.
-- Roles live in team_members, not here.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT        NOT NULL DEFAULT '',
  email       TEXT        UNIQUE,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- TEAMS
-- One team = one travel company / organisation.
-- Start with a single "HOD" team; structure is ready for multi-tenant.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.teams (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT        NOT NULL,
  slug        TEXT        UNIQUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- TEAM MEMBERS
-- Connects users to teams and assigns their role within that team.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.team_members (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id     UUID        NOT NULL REFERENCES public.teams(id)    ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role        TEXT        NOT NULL DEFAULT 'staff'
                          CHECK (role IN ('admin','trip_lead','staff','finance')),
  is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (team_id, user_id)
);

-- =============================================================================
-- TRIPS
-- Core workspace. Everything else belongs to a trip.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.trips (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id          UUID        NOT NULL REFERENCES public.teams(id)    ON DELETE CASCADE,
  trip_name        TEXT        NOT NULL,
  client_name      TEXT        NOT NULL,
  start_date       DATE,
  end_date         DATE,
  number_of_guests INTEGER,
  status           TEXT        NOT NULL DEFAULT 'planning'
                               CHECK (status IN (
                                 'planning','confirmed','in_progress',
                                 'completed','cancelled'
                               )),
  trip_lead_id     UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes            TEXT,
  created_by       UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- TRIP DESTINATIONS
-- Normalized: one row per destination instead of a JSONB array.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.trip_destinations (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id     UUID        NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  city        TEXT,
  country     TEXT,
  sort_order  INTEGER     NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- BOARD GROUPS
-- Monday.com-style columns inside a trip board.
-- Default groups created by app logic on trip creation.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.board_groups (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id     UUID        NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  name        TEXT        NOT NULL,
  sort_order  INTEGER     NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- SUPPLIERS
-- Team-scoped supplier database. Referenced by tasks, itinerary items,
-- cost items, and enrichments.
-- Defined before tasks because tasks has a supplier_id FK.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.suppliers (
  id               UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id          UUID          NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  name             TEXT          NOT NULL,
  category         TEXT          NOT NULL
                                 CHECK (category IN (
                                   'hotel','villa','guide','transport',
                                   'restaurant','experience','concierge','other'
                                 )),
  location         TEXT,
  city             TEXT,
  country          TEXT,
  contact_name     TEXT,
  contact_email    TEXT,
  contact_phone    TEXT,
  website          TEXT,
  preferred        BOOLEAN       NOT NULL DEFAULT FALSE,
  internal_rating  NUMERIC(2,1)
                                 CHECK (internal_rating IS NULL OR
                                       (internal_rating >= 0 AND internal_rating <= 5)),
  notes            TEXT,
  created_by       UUID          REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- SUPPLIER TAGS
-- Reusable tags scoped per team.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.supplier_tags (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id     UUID        NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  name        TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (team_id, name)
);

-- =============================================================================
-- SUPPLIER TAG LINKS
-- Many-to-many join between suppliers and tags.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.supplier_tag_links (
  supplier_id  UUID  NOT NULL REFERENCES public.suppliers(id)     ON DELETE CASCADE,
  tag_id       UUID  NOT NULL REFERENCES public.supplier_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (supplier_id, tag_id)
);

-- =============================================================================
-- SUPPLIER ENRICHMENTS
-- Stores raw + extracted Firecrawl payloads and merge history.
-- supplier_id is nullable — records created before a supplier exists.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.supplier_enrichments (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id        UUID        REFERENCES public.suppliers(id) ON DELETE CASCADE,
  team_id            UUID        NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  source_type        TEXT        NOT NULL
                                 CHECK (source_type IN (
                                   'firecrawl_url','firecrawl_search','manual_import'
                                 )),
  source_url         TEXT,
  source_domain      TEXT,
  raw_payload        JSONB,
  extracted_payload  JSONB,
  action_taken       TEXT
                                 CHECK (action_taken IN (
                                   'created','merged','discarded','draft_only'
                                 )),
  created_by         UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- TRIP DAYS
-- Day-by-day itinerary skeleton. team_id denormalized for simpler RLS.
-- Defined before tasks because tasks has a linked_trip_day_id FK.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.trip_days (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id     UUID        NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  team_id     UUID        NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  day_number  INTEGER     NOT NULL,
  date        DATE,
  city        TEXT,
  title       TEXT,
  sort_order  INTEGER     NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (trip_id, day_number)
);

-- =============================================================================
-- TASKS
-- Core operational table. One task = one action item inside a trip.
-- team_id denormalized for RLS and fast filtering.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.tasks (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id            UUID        NOT NULL REFERENCES public.trips(id)        ON DELETE CASCADE,
  team_id            UUID        NOT NULL REFERENCES public.teams(id)         ON DELETE CASCADE,
  board_group_id     UUID        REFERENCES public.board_groups(id)           ON DELETE SET NULL,
  title              TEXT        NOT NULL,
  description        TEXT,
  category           TEXT,
  status             TEXT        NOT NULL DEFAULT 'not_started'
                                 CHECK (status IN (
                                   'not_started','researching','awaiting_reply',
                                   'ready_for_review','approved','sent_to_client',
                                   'confirmed','cancelled'
                                 )),
  priority           TEXT        NOT NULL DEFAULT 'medium'
                                 CHECK (priority IN ('low','medium','high')),
  assigned_to        UUID        REFERENCES public.profiles(id)  ON DELETE SET NULL,
  destination_city   TEXT,
  travel_date        DATE,
  due_date           DATE,
  supplier_id        UUID        REFERENCES public.suppliers(id) ON DELETE SET NULL,
  linked_trip_day_id UUID        REFERENCES public.trip_days(id) ON DELETE SET NULL,
  cost_status        TEXT        NOT NULL DEFAULT 'pending'
                                 CHECK (cost_status IN ('pending','quoted','approved','paid')),
  is_client_visible  BOOLEAN     NOT NULL DEFAULT FALSE,
  approval_status    TEXT        NOT NULL DEFAULT 'draft'
                                 CHECK (approval_status IN (
                                   'draft','ready_for_review','approved','rejected'
                                 )),
  sort_order         INTEGER     NOT NULL DEFAULT 0,
  created_by         UUID        REFERENCES public.profiles(id)  ON DELETE SET NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- TASK COMMENTS
-- User-written comments on a task.
-- Separated from task_activities (system events) for clarity.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.task_comments (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     UUID        NOT NULL REFERENCES public.tasks(id)    ON DELETE CASCADE,
  author_id   UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  body        TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- TASK ACTIVITIES
-- Immutable audit log of system-generated events on a task.
-- Never edited, never deleted (cascade only on task delete).
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.task_activities (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id        UUID        NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  actor_id       UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  activity_type  TEXT        NOT NULL
                             CHECK (activity_type IN (
                               'status_changed','assigned_user_changed',
                               'comment_added','approval_changed','supplier_linked',
                               'created','updated','deleted'
                             )),
  message        TEXT        NOT NULL,
  metadata       JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- ITINERARY ITEMS
-- Items inside a trip day. team_id denormalized for RLS.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.itinerary_items (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_day_id      UUID        NOT NULL REFERENCES public.trip_days(id)  ON DELETE CASCADE,
  team_id          UUID        NOT NULL REFERENCES public.teams(id)       ON DELETE CASCADE,
  type             TEXT        NOT NULL
                               CHECK (type IN (
                                 'hotel','experience','transport','dining','note'
                               )),
  title            TEXT        NOT NULL,
  description      TEXT,
  start_time       TIME,
  end_time         TIME,
  time_block       TEXT
                               CHECK (time_block IN (
                                 'morning','afternoon','evening','custom'
                               )),
  location         TEXT,
  supplier_id      UUID        REFERENCES public.suppliers(id) ON DELETE SET NULL,
  linked_task_id   UUID        REFERENCES public.tasks(id)     ON DELETE SET NULL,
  status           TEXT        NOT NULL DEFAULT 'draft'
                               CHECK (status IN ('draft','approved','confirmed')),
  approval_status  TEXT        NOT NULL DEFAULT 'draft'
                               CHECK (approval_status IN (
                                 'draft','ready_for_review','approved','rejected'
                               )),
  notes            TEXT,
  sort_order       INTEGER     NOT NULL DEFAULT 0,
  created_by       UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- COST ITEMS
-- Budget / costing module. team_id denormalized for RLS.
-- Can be linked to a task, an itinerary item, or standalone.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.cost_items (
  id                  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id             UUID          NOT NULL REFERENCES public.trips(id)           ON DELETE CASCADE,
  team_id             UUID          NOT NULL REFERENCES public.teams(id)            ON DELETE CASCADE,
  task_id             UUID          REFERENCES public.tasks(id)                     ON DELETE SET NULL,
  itinerary_item_id   UUID          REFERENCES public.itinerary_items(id)           ON DELETE SET NULL,
  supplier_id         UUID          REFERENCES public.suppliers(id)                 ON DELETE SET NULL,
  item_name           TEXT          NOT NULL,
  category            TEXT          NOT NULL,
  city                TEXT,
  service_date        DATE,
  currency            TEXT          NOT NULL DEFAULT 'USD',
  net_cost            NUMERIC(12,2) NOT NULL DEFAULT 0,
  markup_type         TEXT          NOT NULL DEFAULT 'percentage'
                                    CHECK (markup_type IN ('percentage','fixed')),
  markup_value        NUMERIC(12,2) NOT NULL DEFAULT 0,
  sell_price          NUMERIC(12,2) NOT NULL DEFAULT 0,
  payment_status      TEXT          NOT NULL DEFAULT 'pending'
                                    CHECK (payment_status IN (
                                      'pending','due','paid','cancelled'
                                    )),
  payment_due_date    DATE,
  approval_status     TEXT          NOT NULL DEFAULT 'draft'
                                    CHECK (approval_status IN (
                                      'draft','ready_for_review','approved','rejected'
                                    )),
  notes               TEXT,
  created_by          UUID          REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- NOTIFICATIONS
-- In-app notifications. Users see only their own rows (enforced by RLS).
-- related_table + related_id form a polymorphic link to the source record.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  team_id        UUID        NOT NULL REFERENCES public.teams(id)    ON DELETE CASCADE,
  type           TEXT        NOT NULL,
  title          TEXT        NOT NULL,
  message        TEXT        NOT NULL,
  related_table  TEXT,
  related_id     UUID,
  is_read        BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- ATTACHMENTS
-- Generic file attachment table. Polymorphic via related_table + related_id.
-- File storage handled by Supabase Storage; this table is the metadata record.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.attachments (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id        UUID        NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  related_table  TEXT        NOT NULL,  -- 'tasks' | 'suppliers' | 'itinerary_items' | 'cost_items'
  related_id     UUID        NOT NULL,
  file_name      TEXT        NOT NULL,
  file_path      TEXT        NOT NULL,  -- Supabase Storage path
  file_type      TEXT,
  uploaded_by    UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- APPROVAL RECORDS
-- Central audit trail for all approval decisions across entity types.
-- Append-only: never update existing rows, only insert new ones.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.approval_records (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id      UUID        NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  entity_type  TEXT        NOT NULL
                           CHECK (entity_type IN ('task','itinerary_item','cost_item')),
  entity_id    UUID        NOT NULL,
  status       TEXT        NOT NULL
                           CHECK (status IN (
                             'draft','ready_for_review','approved','rejected'
                           )),
  actor_id     UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
