-- =============================================================================
-- component_media join table
--
-- Links trip_components → supplier_media (no file duplication).
-- Run AFTER supplier_media_schema.sql.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.component_media (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id           UUID        NOT NULL REFERENCES public.teams(id)          ON DELETE CASCADE,
  component_id      UUID        NOT NULL REFERENCES public.trip_components(id) ON DELETE CASCADE,
  supplier_media_id UUID        NOT NULL REFERENCES public.supplier_media(id)  ON DELETE CASCADE,

  is_hero           BOOLEAN     NOT NULL DEFAULT FALSE,
  is_visible        BOOLEAN     NOT NULL DEFAULT TRUE,
  caption_override  TEXT,
  display_order     INTEGER,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by        UUID        REFERENCES auth.users(id),

  UNIQUE (component_id, supplier_media_id)
);

-- Enforce at most one hero per component.
CREATE UNIQUE INDEX idx_component_media_hero
  ON public.component_media (component_id)
  WHERE is_hero = TRUE;

CREATE INDEX idx_component_media_component     ON public.component_media (component_id);
CREATE INDEX idx_component_media_supplier_media ON public.component_media (supplier_media_id);

ALTER TABLE public.component_media ENABLE ROW LEVEL SECURITY;
