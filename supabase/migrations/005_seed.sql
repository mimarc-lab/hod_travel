-- =============================================================================
-- HOD Travel — 005_seed.sql
-- Demo seed data — NOT part of the schema migrations.
-- Run manually in Supabase SQL Editor when you want a pre-populated workspace.
-- DO NOT run in production automatically.
--
-- Assumes auth.users already contains at least one real user.
-- Replace the UUIDs below with real auth.users ids from your Supabase project.
-- =============================================================================

-- Replace these with real user UUIDs from your Supabase auth.users table:
-- SELECT id, email FROM auth.users LIMIT 10;

DO $$
DECLARE
  -- ── Paste your real auth.users ids here ───────────────────────────────────
  v_user_admin   UUID := '00000000-0000-0000-0000-000000000001'; -- admin
  v_user_lead    UUID := '00000000-0000-0000-0000-000000000002'; -- trip lead
  v_user_staff1  UUID := '00000000-0000-0000-0000-000000000003'; -- staff
  v_user_finance UUID := '00000000-0000-0000-0000-000000000004'; -- finance

  -- ── Generated IDs ──────────────────────────────────────────────────────────
  v_team_id  UUID := gen_random_uuid();
  v_trip_id  UUID := gen_random_uuid();

BEGIN

  -- ==========================================================================
  -- PROFILES
  -- Normally created automatically via the handle_new_user trigger.
  -- Only needed here if seed runs before real sign-ups.
  -- ==========================================================================

  INSERT INTO public.profiles (id, full_name, email)
  VALUES
    (v_user_admin,   'Sarah Mitchell',  'sarah@hodtravel.com'),
    (v_user_lead,    'James Okafor',    'james@hodtravel.com'),
    (v_user_staff1,  'Mei Chen',        'mei@hodtravel.com'),
    (v_user_finance, 'Priya Sharma',    'priya@hodtravel.com')
  ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        email     = EXCLUDED.email;

  -- ==========================================================================
  -- TEAM
  -- ==========================================================================

  INSERT INTO public.teams (id, name, slug)
  VALUES (v_team_id, 'HOD Travel', 'hod-travel')
  ON CONFLICT DO NOTHING;

  -- ==========================================================================
  -- TEAM MEMBERS
  -- ==========================================================================

  INSERT INTO public.team_members (team_id, user_id, role)
  VALUES
    (v_team_id, v_user_admin,   'admin'),
    (v_team_id, v_user_lead,    'trip_lead'),
    (v_team_id, v_user_staff1,  'staff'),
    (v_team_id, v_user_finance, 'finance')
  ON CONFLICT (team_id, user_id) DO NOTHING;

  -- ==========================================================================
  -- TRIP
  -- ==========================================================================

  INSERT INTO public.trips (
    id, team_id, trip_name, client_name,
    start_date, end_date, number_of_guests,
    status, trip_lead_id, created_by
  )
  VALUES (
    v_trip_id, v_team_id,
    'Amalfi & Sicily — Exclusive',
    'The Harrington Family',
    '2025-09-14', '2025-09-24',
    6,
    'planning',
    v_user_lead, v_user_admin
  )
  ON CONFLICT DO NOTHING;

  -- trip_destinations
  INSERT INTO public.trip_destinations (trip_id, city, country, sort_order)
  VALUES
    (v_trip_id, 'Ravello',  'Italy', 0),
    (v_trip_id, 'Positano', 'Italy', 1),
    (v_trip_id, 'Taormina', 'Italy', 2)
  ON CONFLICT DO NOTHING;

  -- ==========================================================================
  -- BOARD GROUPS
  -- Default groups are created by the trigger on trip insert.
  -- No manual insert needed — listed here for reference only.
  --
  -- Pre-Planning | Accommodation | Experiences | Logistics | Finance | Client Delivery
  -- ==========================================================================

  RAISE NOTICE 'Seed complete. Team ID: %, Trip ID: %', v_team_id, v_trip_id;

END;
$$;
