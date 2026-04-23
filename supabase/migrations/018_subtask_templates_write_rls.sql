-- Migration 018: Add INSERT / UPDATE / DELETE policies for subtask_templates.
--
-- Migration 015 only created a SELECT policy, which means any write from the
-- Supabase client (create/edit/delete subtask template) was silently blocked
-- by Row Level Security.  This migration adds the missing write policies.
--
-- subtask_templates has no team_id column, so we use a simple authenticated
-- check.  The existing SELECT policy is replaced with a FOR ALL policy to
-- keep everything in one place.

DROP POLICY IF EXISTS "subtask_templates: authenticated read" ON public.subtask_templates;

CREATE POLICY "subtask_templates: authenticated full access"
  ON public.subtask_templates FOR ALL
  USING  (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);
