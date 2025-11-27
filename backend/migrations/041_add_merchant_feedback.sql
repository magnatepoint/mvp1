-- ============================================================================
-- Merchant feedback tracking + alias table for merchant/channel overrides
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS spendsense.ml_merchant_feedback (
  feedback_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  txn_id UUID NOT NULL REFERENCES spendsense.txn_fact(txn_id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  original_merchant TEXT,
  corrected_merchant TEXT,
  original_channel TEXT,
  corrected_channel TEXT,
  merchant_hash TEXT NOT NULL,
  used_in_training BOOLEAN NOT NULL DEFAULT FALSE,
  feedback_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ml_merchant_feedback_user_hash
  ON spendsense.ml_merchant_feedback(user_id, merchant_hash)
  WHERE used_in_training = FALSE;

CREATE TABLE IF NOT EXISTS spendsense.merchant_alias (
  alias_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  merchant_hash TEXT NOT NULL,
  alias_pattern TEXT NOT NULL,
  normalized_name TEXT NOT NULL,
  channel_override TEXT,
  usage_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, merchant_hash)
);

COMMIT;

