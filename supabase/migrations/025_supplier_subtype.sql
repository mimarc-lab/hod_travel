-- 025_supplier_subtype.sql
-- Add supplier_type and supplier_subtype columns.
-- Backfills supplier_type from the existing category column so all legacy
-- records are covered without touching any user-visible data.

ALTER TABLE public.suppliers
  ADD COLUMN IF NOT EXISTS supplier_type    TEXT,
  ADD COLUMN IF NOT EXISTS supplier_subtype TEXT;

-- ── Backfill supplier_type from legacy category ───────────────────────────────
UPDATE public.suppliers
SET supplier_type = CASE category
  WHEN 'hotel'       THEN 'accommodation'
  WHEN 'villa'       THEN 'accommodation'
  WHEN 'restaurant'  THEN 'dining'
  WHEN 'transport'   THEN 'transport'
  WHEN 'guide'       THEN 'guide'
  WHEN 'experience'  THEN 'experience_provider'
  WHEN 'concierge'   THEN 'specialist_services'
  ELSE                    'other'
END
WHERE supplier_type IS NULL;

-- ── Backfill supplier_subtype for unambiguous single-category cases ───────────
UPDATE public.suppliers SET supplier_subtype = 'hotel'
  WHERE category = 'hotel'      AND supplier_subtype IS NULL;

UPDATE public.suppliers SET supplier_subtype = 'villa'
  WHERE category = 'villa'      AND supplier_subtype IS NULL;

UPDATE public.suppliers SET supplier_subtype = 'restaurant'
  WHERE category = 'restaurant' AND supplier_subtype IS NULL;

UPDATE public.suppliers SET supplier_subtype = 'other'
  WHERE category = 'other'      AND supplier_subtype IS NULL;

-- ── Index ─────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_suppliers_supplier_type
  ON public.suppliers (team_id, supplier_type);
