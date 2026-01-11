BEGIN;

CREATE TABLE IF NOT EXISTS goal.goal_suggestions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL,
    goal_id             UUID NULL,
    suggestion_type     VARCHAR(64) NOT NULL,     -- 'INCREASE_CONTRIBUTION', 'CUT_EXPENSE', 'ALLOCATE_SURPLUS', ...
    title               TEXT NOT NULL,
    description         TEXT NOT NULL,
    action_payload      JSONB DEFAULT '{}'::jsonb, -- e.g. { "increase_by": 1000, "new_monthly": 5000 }
    status              VARCHAR(16) NOT NULL DEFAULT 'open', -- 'open', 'accepted', 'dismissed'
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_suggestion_goal
      FOREIGN KEY (goal_id) REFERENCES goal.user_goals_master (goal_id)
);

CREATE INDEX IF NOT EXISTS idx_goal_suggestions_user ON goal.goal_suggestions (user_id, status, created_at DESC);

COMMIT;

