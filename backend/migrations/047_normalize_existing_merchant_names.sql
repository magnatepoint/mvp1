-- ============================================================================
-- Migration 047: Normalize existing merchant_name_norm values
-- ============================================================================
-- This migration updates existing merchant_name_norm values to be properly
-- title-cased, matching the new normalization logic in the ETL pipeline.
-- ============================================================================

BEGIN;

-- Update merchant_name_norm in txn_fact to be properly title-cased
-- Update all lowercase or mixed-case values to proper title case
UPDATE spendsense.txn_fact
SET merchant_name_norm = INITCAP(REGEXP_REPLACE(LOWER(TRIM(merchant_name_norm)), '\s+', ' ', 'g'))
WHERE merchant_name_norm IS NOT NULL
  AND merchant_name_norm != ''
  -- Update if the entire string is lowercase (no uppercase letters at all)
  AND merchant_name_norm = LOWER(merchant_name_norm)
  -- Don't update if it's already properly title-cased (has uppercase after first char)
  AND NOT EXISTS (
    SELECT 1 
    FROM regexp_split_to_table(merchant_name_norm, '') AS char
    WHERE char ~ '[A-Z]' 
    LIMIT 1 OFFSET 1  -- Skip first character
  );

-- Also update any merchant names that are just generic terms to NULL
-- This helps identify transactions that need better merchant extraction
UPDATE spendsense.txn_fact
SET merchant_name_norm = NULL
WHERE merchant_name_norm IS NOT NULL
  AND LOWER(TRIM(merchant_name_norm)) IN (
    'to', 'from', 'to transfer', 'from transfer', 'transfer',
    'to transfer from', 'from transfer to', 'transfer to', 'transfer from',
    'payment', 'payment to', 'payment from', 'debit', 'credit',
    'transaction', 'txn', 'tx', 'unknown', 'n/a', 'na'
  );

-- Create index if it doesn't exist for better performance on merchant lookups
CREATE INDEX IF NOT EXISTS idx_txn_fact_merchant_name_norm 
ON spendsense.txn_fact(merchant_name_norm) 
WHERE merchant_name_norm IS NOT NULL;

COMMIT;

