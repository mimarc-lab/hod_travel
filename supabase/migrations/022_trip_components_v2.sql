-- =============================================================================
-- 022_trip_components_v2.sql
-- Enhanced trip_components: universal fields + details_json
-- Removes flight/train/yacht (folded into transport via details_json)
-- =============================================================================

-- 1. Migrate rows with removed types → transport
UPDATE trip_components
  SET component_type = 'transport'::component_type_enum
  WHERE component_type IN ('flight'::component_type_enum,
                           'train'::component_type_enum,
                           'yacht'::component_type_enum);

-- 2. Replace enum (create new, swap, drop old)
CREATE TYPE component_type_enum_v2 AS ENUM (
  'accommodation', 'experience', 'dining', 'transport',
  'guide', 'special_arrangement', 'other'
);

-- Drop the column default first so Postgres can re-type it
ALTER TABLE trip_components
  ALTER COLUMN component_type DROP DEFAULT;

ALTER TABLE trip_components
  ALTER COLUMN component_type TYPE component_type_enum_v2
  USING component_type::text::component_type_enum_v2;

-- Restore default using the new type
ALTER TABLE trip_components
  ALTER COLUMN component_type SET DEFAULT 'other'::component_type_enum_v2;

DROP TYPE component_type_enum;
ALTER TYPE component_type_enum_v2 RENAME TO component_type_enum;

-- 3. Add universal fields
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
