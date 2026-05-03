-- =============================================================================
-- Supabase Storage — supplier-media bucket policies
--
-- Run in Supabase SQL editor AFTER creating the bucket:
--   Storage > New bucket > Name: supplier-media > Public: false
--
-- Path structure: {team_id}/{supplier_id}/{media_id}/{filename}.webp
-- =============================================================================

-- SELECT (download)
CREATE POLICY "team members can read supplier media"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'supplier-media'
    AND (storage.foldername(name))[1] IN (
      SELECT team_id::TEXT FROM public.team_members WHERE user_id = auth.uid()
    )
  );

-- INSERT (upload)
CREATE POLICY "team members can upload supplier media"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'supplier-media'
    AND (storage.foldername(name))[1] IN (
      SELECT team_id::TEXT FROM public.team_members WHERE user_id = auth.uid()
    )
  );

-- UPDATE (replace / upsert)
CREATE POLICY "team members can update supplier media"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'supplier-media'
    AND (storage.foldername(name))[1] IN (
      SELECT team_id::TEXT FROM public.team_members WHERE user_id = auth.uid()
    )
  );

-- DELETE
CREATE POLICY "team members can delete supplier media"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'supplier-media'
    AND (storage.foldername(name))[1] IN (
      SELECT team_id::TEXT FROM public.team_members WHERE user_id = auth.uid()
    )
  );
