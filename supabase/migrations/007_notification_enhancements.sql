-- =============================================================================
-- 007_notification_enhancements.sql
--
-- Adds severity and suggested_action columns to the notifications table.
-- Run this once in Supabase SQL Editor.
-- =============================================================================

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS severity        TEXT NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  ADD COLUMN IF NOT EXISTS suggested_action TEXT;

-- Index for unread deduplication queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications(user_id, is_read, type, related_id);
