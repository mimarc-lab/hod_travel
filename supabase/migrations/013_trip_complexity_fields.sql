-- Migration 013: Trip complexity fields for Hybrid Schedule Engine
--
-- These boolean flags are read by HybridScheduleEngine at trip-creation time
-- to apply complexity-based duration adjustments to template tasks.
-- All default to FALSE so existing trips are unaffected.

ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS has_signature_experiences BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS has_mobility_requirements BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS has_private_transport      BOOLEAN NOT NULL DEFAULT FALSE;
