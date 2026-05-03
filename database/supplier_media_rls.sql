-- =============================================================================
-- Row Level Security — supplier_media
-- Team-scoped: members can only see and mutate media that belongs to
-- their own team. Matches the pattern used across the rest of the schema.
-- =============================================================================

ALTER TABLE public.supplier_media ENABLE ROW LEVEL SECURITY;

-- ── Helper: resolve the caller's team_id from their profile ──────────────────
-- (Reuses the same approach as other RLS policies in this project.)

-- SELECT — any authenticated team member can read their team's media
CREATE POLICY "team members can view supplier media"
  ON public.supplier_media
  FOR SELECT
  TO authenticated
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid()
    )
  );

-- INSERT — team members can upload to their own team
CREATE POLICY "team members can insert supplier media"
  ON public.supplier_media
  FOR INSERT
  TO authenticated
  WITH CHECK (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid()
    )
  );

-- UPDATE — team members can edit their team's media
CREATE POLICY "team members can update supplier media"
  ON public.supplier_media
  FOR UPDATE
  TO authenticated
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid()
    )
  );

-- DELETE — team members can remove their team's media
CREATE POLICY "team members can delete supplier media"
  ON public.supplier_media
  FOR DELETE
  TO authenticated
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid()
    )
  );
