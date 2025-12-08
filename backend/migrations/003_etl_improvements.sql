-- ============================================================================
-- ETL Improvements Migration
-- Consolidates: 003, 019, 020, 021, 036_add_bank_channel_metadata, 045
-- Adds parsed event lineage, dedupe fingerprints, audit fields, materialized views,
-- bank channel metadata, and fixes txn_staging column names
-- ============================================================================
-- This allows tracing PostgreSQL transactions back to MongoDB parsed_events

-- Add parsed_event_oid to txn_staging
ALTER TABLE spendsense.txn_staging
  ADD COLUMN IF NOT EXISTS parsed_event_oid text;

-- Add parsed_event_oid to txn_fact
ALTER TABLE spendsense.txn_fact
  ADD COLUMN IF NOT EXISTS parsed_event_oid text;

-- Create indexes for lineage queries
CREATE INDEX IF NOT EXISTS idx_txn_staging_parsed_event_oid 
  ON spendsense.txn_staging(parsed_event_oid);

CREATE INDEX IF NOT EXISTS idx_txn_fact_parsed_event_oid 
  ON spendsense.txn_fact(parsed_event_oid);

-- Add unique soft constraint (optional, for additional safety)
-- This prevents duplicates at PostgreSQL level even if dedupe_key fails
-- Note: txn_fact uses txn_external_id (not raw_txn_id)
CREATE UNIQUE INDEX IF NOT EXISTS idx_txn_fact_soft_dedup
  ON spendsense.txn_fact(
    user_id,
    txn_date,
    amount,
    direction,
    COALESCE(txn_external_id, ''),
    COALESCE(merchant_name_norm, '')
  )
  WHERE txn_external_id IS NOT NULL OR merchant_name_norm IS NOT NULL;

-- =========================================================
-- Add Dedupe Fingerprint and Performance Indexes
-- 1. Add dedupe_fp column and function
-- 2. Create unique index for duplicate prevention
-- 3. Add performance indexes for hot paths
-- =========================================================

BEGIN;

-- ---------- DEDUPE FINGERPRINT ----------

-- Add dedupe_fp column if not exists
ALTER TABLE spendsense.txn_fact
ADD COLUMN IF NOT EXISTS dedupe_fp text;

-- Create fingerprint function
CREATE OR REPLACE FUNCTION spendsense.fn_txn_fact_fp(
    p_user uuid, 
    p_date date, 
    p_amt numeric, 
    p_dir text, 
    p_desc text, 
    p_merch text, 
    p_acct text
) RETURNS text LANGUAGE sql IMMUTABLE AS $$
SELECT encode(
  digest(
    coalesce(p_user::text,'') || '|' ||
    coalesce(p_date::text,'') || '|' ||
    coalesce(trim(to_char(p_amt, 'FM9999999990.00')),'') || '|' ||
    coalesce(lower(p_dir),'') || '|' ||
    coalesce(lower(regexp_replace(p_desc,'\s+',' ','g')),'') || '|' ||
    coalesce(lower(p_merch),'') || '|' ||
    coalesce(lower(p_acct),'')
  , 'sha1'), 'hex');
$$;

COMMENT ON FUNCTION spendsense.fn_txn_fact_fp IS 'Generate dedupe fingerprint for transactions';

-- Create unique index on dedupe_fp
CREATE UNIQUE INDEX IF NOT EXISTS ux_txn_fact_dedupe_fp
ON spendsense.txn_fact(dedupe_fp)
WHERE dedupe_fp IS NOT NULL;

-- Backfill existing rows (optional, but recommended)
UPDATE spendsense.txn_fact
SET dedupe_fp = spendsense.fn_txn_fact_fp(
    user_id,
    txn_date,
    amount,
    direction,
    COALESCE(description, ''),
    COALESCE(merchant_name_norm, ''),
    COALESCE(account_ref::text, '')
)
WHERE dedupe_fp IS NULL;

-- ---------- PERFORMANCE INDEXES ----------

-- Staging hot paths
CREATE INDEX IF NOT EXISTS ix_txn_staging_user 
ON spendsense.txn_staging(user_id);

CREATE INDEX IF NOT EXISTS ix_txn_staging_user_date 
ON spendsense.txn_staging(user_id, txn_date);

CREATE INDEX IF NOT EXISTS ix_txn_staging_upload 
ON spendsense.txn_staging(upload_id);

CREATE INDEX IF NOT EXISTS ix_txn_staging_parsed 
ON spendsense.txn_staging(parsed_ok) 
WHERE parsed_ok = true;

-- Enriched lookups
CREATE INDEX IF NOT EXISTS ix_txn_enriched_txn 
ON spendsense.txn_enriched(txn_id);

CREATE INDEX IF NOT EXISTS ix_txn_enriched_cat 
ON spendsense.txn_enriched(category_code, subcategory_code)
WHERE category_code IS NOT NULL;

-- Fact queries (lists / dashboards)
CREATE INDEX IF NOT EXISTS ix_txn_fact_user_date 
ON spendsense.txn_fact(user_id, txn_date DESC);

CREATE INDEX IF NOT EXISTS ix_txn_fact_user_amt_dir 
ON spendsense.txn_fact(user_id, amount, direction);

CREATE INDEX IF NOT EXISTS ix_txn_fact_user_dir 
ON spendsense.txn_fact(user_id, direction)
WHERE direction IN ('debit', 'credit');

COMMIT;

-- =========================================================
-- Add ETL Audit Fields
-- Track how transactions were ingested for debugging
-- =========================================================

BEGIN;

-- Add audit fields to txn_fact
ALTER TABLE spendsense.txn_fact
  ADD COLUMN IF NOT EXISTS ingested_via text,
  ADD COLUMN IF NOT EXISTS raw_source_id uuid;

-- Add index on ingested_via for filtering
CREATE INDEX IF NOT EXISTS ix_txn_fact_ingested_via
ON spendsense.txn_fact(ingested_via)
WHERE ingested_via IS NOT NULL;

-- Add index on raw_source_id for tracking
CREATE INDEX IF NOT EXISTS ix_txn_fact_raw_source_id
ON spendsense.txn_fact(raw_source_id)
WHERE raw_source_id IS NOT NULL;

COMMENT ON COLUMN spendsense.txn_fact.ingested_via IS 'Source of ingestion: file, manual, etc.';
COMMENT ON COLUMN spendsense.txn_fact.raw_source_id IS 'Reference to upload_batch.upload_id';

COMMIT;

-- =========================================================
-- Update Materialized Views to Exclude Transfers
-- Ensure KPI calculations exclude transfers category
-- =========================================================

BEGIN;

-- Check if materialized views exist and update them
-- Note: We need to DROP and recreate since we can't ALTER materialized views

-- Drop existing views if they exist
DROP MATERIALIZED VIEW IF EXISTS spendsense.mv_spendsense_dashboard_user_month;
DROP MATERIALIZED VIEW IF EXISTS spendsense.mv_spendsense_insights_user_month;

-- Recreate dashboard view with transfers exclusion
CREATE MATERIALIZED VIEW spendsense.mv_spendsense_dashboard_user_month AS
SELECT
    tf.user_id,
    date_trunc('month', tf.txn_date)::date AS month,
    SUM(CASE WHEN tf.direction = 'credit' THEN tf.amount ELSE 0 END) AS income_amt,
    SUM(CASE WHEN tf.direction = 'debit' 
             AND COALESCE(dc.txn_type,'wants') = 'needs' 
             AND COALESCE(te.category_code,'') <> 'transfers'
             THEN tf.amount ELSE 0 END) AS needs_amt,
    SUM(CASE WHEN tf.direction = 'debit' 
             AND COALESCE(dc.txn_type,'wants') = 'wants' 
             AND COALESCE(te.category_code,'') <> 'transfers'
             THEN tf.amount ELSE 0 END) AS wants_amt,
    SUM(CASE WHEN tf.direction = 'debit' 
             AND COALESCE(dc.txn_type,'wants') = 'assets' 
             AND COALESCE(te.category_code,'') <> 'transfers'
             THEN tf.amount ELSE 0 END) AS assets_amt,
    NOW() AS created_at
FROM spendsense.txn_fact tf
LEFT JOIN spendsense.txn_enriched te ON te.txn_id = tf.txn_id
LEFT JOIN spendsense.dim_category dc ON dc.category_code = te.category_code
WHERE COALESCE(te.category_code,'') <> 'transfers'
GROUP BY tf.user_id, date_trunc('month', tf.txn_date);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_dash_user_month 
ON spendsense.mv_spendsense_dashboard_user_month(user_id, month);

-- Recreate insights view with transfers exclusion
CREATE MATERIALIZED VIEW spendsense.mv_spendsense_insights_user_month AS
SELECT
    tf.user_id,
    date_trunc('month', tf.txn_date)::date AS month,
    COALESCE(te.category_code,'others') AS category_code,
    COUNT(*) AS txn_count,
    SUM(CASE WHEN tf.direction = 'debit' THEN tf.amount ELSE 0 END) AS spend_amt,
    SUM(CASE WHEN tf.direction = 'credit' THEN tf.amount ELSE 0 END) AS income_amt
FROM spendsense.txn_fact tf
LEFT JOIN spendsense.txn_enriched te ON te.txn_id = tf.txn_id
WHERE COALESCE(te.category_code,'') <> 'transfers'
GROUP BY tf.user_id, date_trunc('month', tf.txn_date), COALESCE(te.category_code,'others');

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_insights_user_month 
ON spendsense.mv_spendsense_insights_user_month(user_id, month, category_code);

COMMENT ON MATERIALIZED VIEW spendsense.mv_spendsense_dashboard_user_month IS 'Dashboard KPIs excluding transfers';
COMMENT ON MATERIALIZED VIEW spendsense.mv_spendsense_insights_user_month IS 'Insights by category excluding transfers';

COMMIT;

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

-- ============================================================================
-- Fix txn_staging column name: rename "debit/credit" to "direction"
-- ============================================================================
BEGIN;

-- Rename the column from "debit/credit" to "direction" in txn_staging
-- Only rename if "debit/credit" exists and "direction" doesn't exist
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'spendsense' 
        AND table_name = 'txn_staging' 
        AND column_name = 'debit/credit'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'spendsense' 
        AND table_name = 'txn_staging' 
        AND column_name = 'direction'
    ) THEN
        ALTER TABLE spendsense.txn_staging RENAME COLUMN "debit/credit" TO direction;
    END IF;
END $$;

-- Also fix the Bank_name column (should be bank_code based on migration 036)
-- Check if Bank_name exists and rename it to bank_code if needed
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'spendsense' 
        AND table_name = 'txn_staging' 
        AND column_name = 'Bank_name'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'spendsense' 
        AND table_name = 'txn_staging' 
        AND column_name = 'bank_code'
    ) THEN
        ALTER TABLE spendsense.txn_staging RENAME COLUMN "Bank_name" TO bank_code;
    END IF;
END $$;

COMMIT;

