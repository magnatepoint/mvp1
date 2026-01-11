-- Migration: Create table for storing computed money moments (behavioral insights)
BEGIN;

CREATE TABLE IF NOT EXISTS moneymoments.mm_user_moments (
    user_id UUID NOT NULL,
    month VARCHAR(7) NOT NULL,  -- Format: 'YYYY-MM'
    habit_id VARCHAR(64) NOT NULL,
    value NUMERIC(14,4) NOT NULL,
    label VARCHAR(120) NOT NULL,
    insight_text TEXT NOT NULL,
    confidence NUMERIC(3,2) NOT NULL CHECK (confidence >= 0.0 AND confidence <= 1.0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, month, habit_id)
);

CREATE INDEX IF NOT EXISTS idx_mm_user_moments_user_month ON moneymoments.mm_user_moments(user_id, month DESC);
CREATE INDEX IF NOT EXISTS idx_mm_user_moments_habit ON moneymoments.mm_user_moments(habit_id);

COMMIT;

