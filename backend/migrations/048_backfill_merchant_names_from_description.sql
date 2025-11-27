-- ============================================================================
-- Migration 048: Backfill merchant_name_norm from description for NULL values
-- ============================================================================
-- This migration extracts merchant names from transaction descriptions when
-- merchant_name_norm is NULL, particularly for UPI transactions with patterns like:
-- "TO TRANSFER-UPI/DR/{ref}/{merchant}/{bank}/..."
-- ============================================================================

BEGIN;

-- Update merchant_name_norm from description for transactions where it's NULL
UPDATE spendsense.txn_fact
SET merchant_name_norm = INITCAP(REGEXP_REPLACE(
    CASE 
        -- Pattern: TO TRANSFER-UPI/DR/{ref}/{merchant}/{bank}/...
        WHEN description ~* '^TO TRANSFER-UPI/DR/[^/]+/([^/]+)/' THEN
            (regexp_match(description, '^TO TRANSFER-UPI/DR/[^/]+/([^/]+)/'))[1]
        -- Pattern: UPI-{merchant}-...
        WHEN description ~* '^UPI-([^-]+)-' THEN
            (regexp_match(description, '^UPI-([^-]+)-'))[1]
        -- Pattern: UPI/{merchant}/
        WHEN description ~* 'UPI/([^/]+)/' THEN
            (regexp_match(description, 'UPI/([^/]+)/'))[1]
        -- Pattern: IMPS-{ref}-{merchant}-... or BY TRANSFER-IMPS/{ref}/{merchant}/
        WHEN description ~* '^IMPS-[^-]+-([^-]+)-' THEN
            (regexp_match(description, '^IMPS-[^-]+-([^-]+)-'))[1]
        WHEN description ~* 'BY TRANSFER-IMPS/[^/]+/([^/]+)/' THEN
            (regexp_match(description, 'BY TRANSFER-IMPS/[^/]+/([^/]+)/'))[1]
        -- Pattern: NEFT CR-{ref}-{merchant} or NEFT/{merchant}
        WHEN description ~* 'NEFT\s+CR-[^-]+-([^-]+)' THEN
            (regexp_match(description, 'NEFT\s+CR-[^-]+-([^-]+)'))[1]
        WHEN description ~* '(NEFT|NEFT)[-/]([^-/\s]+)' THEN
            (regexp_match(description, '(NEFT|NEFT)[-/]([^-/\s]+)'))[2]
        -- Pattern: ACH {merchant}
        WHEN description ~* '^ACH\s+([^-/]+)' THEN
            (regexp_match(description, '^ACH\s+([^-/]+)'))[1]
        -- For simple descriptions (not too long, not generic), use the description itself
        WHEN LENGTH(TRIM(description)) > 0 
             AND LENGTH(TRIM(description)) <= 50
             AND LOWER(TRIM(description)) NOT IN ('test transaction - today', 'salary', 'payment', 'transfer', 'debit', 'credit')
             AND description !~* '^\d+$'  -- Not just numbers
        THEN TRIM(description)
        -- Use bank_code as fallback for empty descriptions
        WHEN (description IS NULL OR description = '') AND bank_code IS NOT NULL THEN
            REPLACE(bank_code, '_', ' ')
        ELSE NULL
    END,
    '\s+', ' ', 'g'
))
WHERE merchant_name_norm IS NULL
  AND description IS NOT NULL
  AND description != '';

-- Clean up extracted merchant names (remove common suffixes/prefixes)
UPDATE spendsense.txn_fact
SET merchant_name_norm = TRIM(REGEXP_REPLACE(merchant_name_norm, '\s+(PAYU|PAYTM|RAZORPAY|BILLDESK|ICICI|HDFC|SBI|YESB|UTIB|SBIN)\s*$', '', 'i'))
WHERE merchant_name_norm IS NOT NULL
  AND merchant_name_norm ~* '\s+(PAYU|PAYTM|RAZORPAY|BILLDESK|ICICI|HDFC|SBI|YESB|UTIB|SBIN)\s*$';

-- Remove generic/meaningless merchant names
UPDATE spendsense.txn_fact
SET merchant_name_norm = NULL
WHERE merchant_name_norm IS NOT NULL
  AND LOWER(TRIM(merchant_name_norm)) IN (
    'to', 'from', 'transfer', 'payment', 'debit', 'credit',
    'dr', 'cr', 'txn', 'transaction', 'unknown', 'n/a', 'na',
    'upi', 'ach', 'neft', 'imps', 'rtgs'
  );

COMMIT;

