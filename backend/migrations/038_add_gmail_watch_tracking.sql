-- ============================================================================
-- Gmail Watch tracking for real-time notifications
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS spendsense.gmail_watch (
  user_id UUID PRIMARY KEY,
  watch_id TEXT NOT NULL,
  history_id TEXT NOT NULL,
  topic_name TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES spendsense.gmail_connection(user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_gmail_watch_expires ON spendsense.gmail_watch(expires_at);

COMMIT;

