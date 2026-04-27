-- =============================================================================
-- Supabase Storage — trip-documents bucket
-- Run AFTER creating the bucket in Dashboard → Storage → New bucket
-- Bucket name: trip-documents   (private, not public)
-- =============================================================================

-- ── Create bucket (if using SQL rather than the dashboard) ───────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'trip-documents',
  'trip-documents',
  false,   -- private: signed URLs required for access
  52428800, -- 50 MB per file
  ARRAY[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain',
    'text/csv'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- Storage policies
-- Path convention: {team_id}/{trip_id}/{doc_id}/{file_name}
-- Policy: authenticated user must belong to the team_id in the path prefix.
-- =============================================================================

-- ── SELECT (download) ─────────────────────────────────────────────────────────

CREATE POLICY "team_members_can_download"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'trip-documents'
    AND (storage.foldername(name))[1] IN (
      SELECT team_id::text FROM team_members
      WHERE user_id = auth.uid()
    )
  );

-- ── INSERT (upload) ──────────────────────────────────────────────────────────

CREATE POLICY "team_members_can_upload"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'trip-documents'
    AND (storage.foldername(name))[1] IN (
      SELECT team_id::text FROM team_members
      WHERE user_id = auth.uid()
    )
  );

-- ── UPDATE (replace file) ────────────────────────────────────────────────────

CREATE POLICY "team_members_can_replace"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'trip-documents'
    AND (storage.foldername(name))[1] IN (
      SELECT team_id::text FROM team_members
      WHERE user_id = auth.uid()
    )
  );

-- ── DELETE (remove file) ─────────────────────────────────────────────────────

CREATE POLICY "team_members_can_delete_files"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'trip-documents'
    AND (storage.foldername(name))[1] IN (
      SELECT team_id::text FROM team_members
      WHERE user_id = auth.uid()
    )
  );
