-- ============================================================================
-- Add email address to gmail_connection for user lookup
-- ============================================================================
BEGIN;

ALTER TABLE spendsense.gmail_connection
ADD COLUMN IF NOT EXISTS email_address VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_gmail_connection_email ON spendsense.gmail_connection(email_address);

COMMIT;

