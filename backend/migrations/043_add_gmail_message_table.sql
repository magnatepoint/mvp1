-- ============================================================================
-- Track processed Gmail messages for idempotency
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS spendsense.gmail_message (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gmail_account_id UUID NOT NULL REFERENCES spendsense.gmail_connection(user_id) ON DELETE CASCADE,
  gmail_message_id TEXT NOT NULL,
  history_id BIGINT NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  success BOOLEAN NOT NULL DEFAULT TRUE,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (gmail_account_id, gmail_message_id)
);

COMMIT;


