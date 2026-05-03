-- ─────────────────────────────────────────────────────────────────────────────
-- share_tokens
--
-- UUID primary key acts as the cryptographically secure token.
-- Token appears directly in the share URL: /share/<uuid>
-- expires_at NULL means the token never expires.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.share_tokens (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id    UUID        NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  created_by UUID        REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

ALTER TABLE public.share_tokens ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_share_tokens_trip_id ON public.share_tokens (trip_id);
