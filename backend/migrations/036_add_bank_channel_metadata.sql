-- ============================================================================
-- Add bank metadata & channel classification
-- ============================================================================
BEGIN;

ALTER TABLE spendsense.txn_staging
    ADD COLUMN IF NOT EXISTS bank_code TEXT,
    ADD COLUMN IF NOT EXISTS channel TEXT;

ALTER TABLE spendsense.txn_fact
    ADD COLUMN IF NOT EXISTS bank_code TEXT,
    ADD COLUMN IF NOT EXISTS channel TEXT;

DROP VIEW IF EXISTS spendsense.vw_txn_effective;

CREATE OR REPLACE VIEW spendsense.vw_txn_effective AS
WITH last_override AS (
  SELECT DISTINCT ON (o.txn_id)
    o.txn_id, o.category_code, o.subcategory_code, o.txn_type, o.created_at
  FROM spendsense.txn_override o
  ORDER BY o.txn_id, o.created_at DESC
)
SELECT
  f.txn_id,
  f.user_id,
  f.txn_date,
  f.amount,
  f.direction,
  f.currency,
  f.description,
  COALESCE(lo.category_code, e.category_code) AS category_code,
  COALESCE(lo.subcategory_code, e.subcategory_code) AS subcategory_code,
  CASE
    WHEN lo.txn_type IS NOT NULL THEN lo.txn_type
    WHEN e.txn_type IS NOT NULL THEN e.txn_type
    WHEN f.direction = 'credit' THEN 'income'
    ELSE (
      SELECT dc.txn_type
      FROM spendsense.dim_category dc
      WHERE dc.category_code = COALESCE(lo.category_code, e.category_code)
    )
  END AS txn_type,
  f.merchant_id,
  f.merchant_name_norm,
  f.bank_code,
  f.channel
FROM spendsense.txn_fact f
LEFT JOIN spendsense.txn_enriched e ON e.txn_id = f.txn_id
LEFT JOIN last_override lo ON lo.txn_id = f.txn_id;

COMMIT;

