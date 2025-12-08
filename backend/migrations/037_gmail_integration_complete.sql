-- ============================================================================
-- Gmail Integration Complete Migration
-- Consolidates: 037, 038, 039, 043
-- Creates Gmail OAuth tables, watch tracking, email connection, and message tracking
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

-- ============================================================================
-- Add email address to gmail_connection for user lookup
-- ============================================================================
BEGIN;

ALTER TABLE spendsense.gmail_connection
ADD COLUMN IF NOT EXISTS email_address VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_gmail_connection_email ON spendsense.gmail_connection(email_address);

COMMIT;

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


