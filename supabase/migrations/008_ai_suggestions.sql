-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 008: AI Suggestions
--
-- Creates the ai_suggestions table used by Phase 19 (AI Suggestion Layer).
-- Stores AI-generated suggestions for trips, with a JSONB proposed_payload
-- that holds the type-specific data the suggestion wants to apply.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Table ─────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS ai_suggestions (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id          UUID         NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    team_id          UUID         NOT NULL REFERENCES teams(id) ON DELETE CASCADE,

    type             TEXT         NOT NULL
                       CHECK (type IN (
                           'draft_itinerary',
                           'missing_gap',
                           'supplier_recommendation',
                           'signature_experience',
                           'task_suggestion',
                           'flow_improvement'
                       )),

    title            TEXT         NOT NULL,
    description      TEXT         NOT NULL DEFAULT '',
    rationale        TEXT,

    target_entity_type TEXT,
    target_entity_id   UUID,

    -- Flexible JSON payload holding the type-specific pre-fill data.
    proposed_payload JSONB        NOT NULL DEFAULT '{}',

    -- Snapshot of the trip context at generation time (for debugging/audit).
    source_context   JSONB        NOT NULL DEFAULT '{}',

    status           TEXT         NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending', 'approved', 'dismissed', 'applied')),

    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    reviewed_at      TIMESTAMPTZ
);

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS ai_suggestions_trip_id_idx
    ON ai_suggestions (trip_id);

CREATE INDEX IF NOT EXISTS ai_suggestions_team_id_idx
    ON ai_suggestions (team_id);

CREATE INDEX IF NOT EXISTS ai_suggestions_status_idx
    ON ai_suggestions (status);

CREATE INDEX IF NOT EXISTS ai_suggestions_created_at_idx
    ON ai_suggestions (created_at DESC);

-- ── RLS ───────────────────────────────────────────────────────────────────────

ALTER TABLE ai_suggestions ENABLE ROW LEVEL SECURITY;

-- Team members can read suggestions for their team's trips.
CREATE POLICY "Team members can read ai_suggestions"
    ON ai_suggestions FOR SELECT
    USING (
        team_id IN (
            SELECT team_id FROM team_members
            WHERE user_id = auth.uid()
        )
    );

-- Team members can insert suggestions.
CREATE POLICY "Team members can insert ai_suggestions"
    ON ai_suggestions FOR INSERT
    WITH CHECK (
        team_id IN (
            SELECT team_id FROM team_members
            WHERE user_id = auth.uid()
        )
    );

-- Team members can update suggestions (approve / dismiss / edit payload).
CREATE POLICY "Team members can update ai_suggestions"
    ON ai_suggestions FOR UPDATE
    USING (
        team_id IN (
            SELECT team_id FROM team_members
            WHERE user_id = auth.uid()
        )
    );

-- Team members can delete suggestions.
CREATE POLICY "Team members can delete ai_suggestions"
    ON ai_suggestions FOR DELETE
    USING (
        team_id IN (
            SELECT team_id FROM team_members
            WHERE user_id = auth.uid()
        )
    );
