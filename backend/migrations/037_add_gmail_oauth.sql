-- ============================================================================
-- Gmail OAuth tables
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS spendsense.gmail_connection (
  user_id UUID PRIMARY KEY,
  access_token TEXT NOT NULL,
  refresh_token TEXT NOT NULL,
  token_expiry TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS spendsense.gmail_sync_job (
  job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  status VARCHAR(16) NOT NULL CHECK (status IN ('queued','authorizing','syncing','completed','failed')),
  progress SMALLINT NOT NULL DEFAULT 0,
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gmail_job_user ON spendsense.gmail_sync_job(user_id, created_at DESC);

COMMIT;

