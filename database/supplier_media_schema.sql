-- =============================================================================
-- supplier_media table
-- Stores metadata only. Binary assets live in Supabase Storage
-- bucket: supplier-media   path: {team_id}/{supplier_id}/{media_id}/{file}.webp
--
-- Reusable across trips: supplier_id is the anchor; no trip_id column.
-- Components and Client View reference supplier_media.id later (Step 2+).
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.supplier_media (
  -- Identity
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id         UUID NOT NULL REFERENCES public.teams(id)     ON DELETE CASCADE,
  supplier_id     UUID NOT NULL REFERENCES public.suppliers(id) ON DELETE CASCADE,

  -- Media type & URLs
  media_type      TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
  file_url        TEXT NOT NULL,
  thumbnail_url   TEXT,
  storage_path    TEXT NOT NULL DEFAULT '',
  mime_type       TEXT,

  -- Video-specific (external YouTube/Vimeo or hosted MP4)
  video_url       TEXT,

  -- Details
  title           TEXT NOT NULL DEFAULT '',
  description     TEXT,
  caption         TEXT,

  -- Flags
  is_hero         BOOLEAN NOT NULL DEFAULT FALSE,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,

  -- Organisation
  display_order   INTEGER,
  tags            JSONB NOT NULL DEFAULT '[]'::JSONB,

  -- Audit
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  uploaded_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- ── Indexes ──────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_supplier_media_supplier
  ON public.supplier_media (supplier_id)
  WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_supplier_media_team
  ON public.supplier_media (team_id);

CREATE INDEX IF NOT EXISTS idx_supplier_media_order
  ON public.supplier_media (supplier_id, display_order NULLS LAST)
  WHERE is_active = TRUE;

-- Partial index: enforce at most one hero per supplier at the DB level.
-- A unique index on (supplier_id) WHERE is_hero = TRUE prevents duplicates.
CREATE UNIQUE INDEX IF NOT EXISTS idx_supplier_media_one_hero
  ON public.supplier_media (supplier_id)
  WHERE is_hero = TRUE AND is_active = TRUE;

-- ── Comments ──────────────────────────────────────────────────────────────────

COMMENT ON TABLE  public.supplier_media IS
  'Reusable media library for each supplier. No trip dependency — assets are '
  'referenced by trip components and client view in later steps.';

COMMENT ON COLUMN public.supplier_media.storage_path IS
  'Supabase Storage path: {team_id}/{supplier_id}/{media_id}/{filename}.webp';

COMMENT ON COLUMN public.supplier_media.video_url IS
  'External video URL (YouTube / Vimeo). Null for uploaded MP4 files.';

COMMENT ON COLUMN public.supplier_media.is_hero IS
  'Exactly one hero per supplier (enforced by partial unique index). '
  'Used as the primary image in component cards and client view banners.';
