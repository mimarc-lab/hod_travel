-- =============================================================================
-- 022_trip_components_v2.sql  (idempotent — safe to re-run at any stage)
-- Enhanced trip_components: universal fields + details_json
-- Removes flight/train/yacht (folded into transport via details_json)
-- =============================================================================

-- 1. Migrate rows only if 'flight' is still a valid enum value
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'component_type_enum' AND e.enumlabel = 'flight'
  ) THEN
    UPDATE trip_components
      SET component_type = 'transport'::text::component_type_enum
      WHERE component_type::text IN ('flight', 'train', 'yacht');
  END IF;
END $$;

-- 2. Swap the enum only if the old 10-value type is still in place
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'component_type_enum' AND e.enumlabel = 'flight'
  ) THEN
    -- Clean up any leftover v2 from a prior failed run
    DROP TYPE IF EXISTS component_type_enum_v2;

    CREATE TYPE component_type_enum_v2 AS ENUM (
      'accommodation', 'experience', 'dining', 'transport',
      'guide', 'special_arrangement', 'other'
    );

    ALTER TABLE trip_components
      ALTER COLUMN component_type DROP DEFAULT;

    ALTER TABLE trip_components
      ALTER COLUMN component_type TYPE component_type_enum_v2
      USING component_type::text::component_type_enum_v2;

    ALTER TABLE trip_components
      ALTER COLUMN component_type SET DEFAULT 'other'::component_type_enum_v2;

    DROP TYPE component_type_enum;
    ALTER TYPE component_type_enum_v2 RENAME TO component_type_enum;
  END IF;
END $$;

-- 3. Add universal fields (IF NOT EXISTS makes each line idempotent)
ALTER TABLE trip_components
  ADD COLUMN IF NOT EXISTS supplier_contact_override_name  TEXT,
  ADD COLUMN IF NOT EXISTS supplier_contact_override_phone TEXT,
  ADD COLUMN IF NOT EXISTS supplier_contact_override_email TEXT,
  ADD COLUMN IF NOT EXISTS supplier_booking_reference      TEXT,
  ADD COLUMN IF NOT EXISTS confirmation_number             TEXT,
  ADD COLUMN IF NOT EXISTS primary_contact_name            TEXT,
  ADD COLUMN IF NOT EXISTS primary_contact_phone           TEXT,
  ADD COLUMN IF NOT EXISTS primary_contact_email           TEXT,
  ADD COLUMN IF NOT EXISTS net_cost                        NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS deposit_paid                    NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS remaining_balance               NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS payment_due_date                DATE,
  ADD COLUMN IF NOT EXISTS cancellation_terms              TEXT,
  ADD COLUMN IF NOT EXISTS confirmation_file_url           TEXT,
  ADD COLUMN IF NOT EXISTS invoice_file_url                TEXT,
  ADD COLUMN IF NOT EXISTS voucher_file_url                TEXT,
  ADD COLUMN IF NOT EXISTS details_json                    JSONB NOT NULL DEFAULT '{}';
