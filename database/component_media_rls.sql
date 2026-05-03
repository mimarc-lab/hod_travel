-- =============================================================================
-- RLS policies for component_media
-- =============================================================================

-- SELECT
CREATE POLICY "team members can read component media"
  ON public.component_media FOR SELECT TO authenticated
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members WHERE user_id = auth.uid()
    )
  );

-- INSERT
CREATE POLICY "team members can insert component media"
  ON public.component_media FOR INSERT TO authenticated
  WITH CHECK (
    team_id IN (
      SELECT team_id FROM public.team_members WHERE user_id = auth.uid()
    )
  );

-- UPDATE
CREATE POLICY "team members can update component media"
  ON public.component_media FOR UPDATE TO authenticated
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members WHERE user_id = auth.uid()
    )
  );

-- DELETE
CREATE POLICY "team members can delete component media"
  ON public.component_media FOR DELETE TO authenticated
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members WHERE user_id = auth.uid()
    )
  );
