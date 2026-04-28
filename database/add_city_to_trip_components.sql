-- =============================================================================
-- Migration: add city column to trip_components
-- Run in Supabase SQL editor (Dashboard → SQL Editor → New query)
-- =============================================================================

ALTER TABLE trip_components
  ADD COLUMN IF NOT EXISTS city TEXT;
