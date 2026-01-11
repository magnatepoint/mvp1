BEGIN;

CREATE TABLE IF NOT EXISTS goal.goal_signals (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL,
    goal_id             UUID NULL,
    signal_type         VARCHAR(64) NOT NULL,       -- e.g. 'DRIFT', 'SURPLUS_INCOME', 'OVERSPEND'
    severity            VARCHAR(16) NOT NULL,       -- 'info', 'warning', 'critical'
    message             TEXT NOT NULL,
    meta                JSONB DEFAULT '{}'::jsonb,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at         TIMESTAMPTZ NULL,
    CONSTRAINT fk_signal_goal
      FOREIGN KEY (goal_id) REFERENCES goal.user_goals_master (goal_id)
);

CREATE INDEX IF NOT EXISTS idx_goal_signals_user ON goal.goal_signals (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_goal_signals_goal ON goal.goal_signals (goal_id);

COMMIT;

