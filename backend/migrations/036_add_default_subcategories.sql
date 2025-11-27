-- ============================================================================
-- Add Default Subcategories for Transactions Without Matches
-- Updates enrichment logic to assign default subcategories when rules match
-- but don't provide a subcategory, or when falling back to default category
-- ============================================================================

BEGIN;

-- Update loan_payments rules that don't have subcategory to use a default
-- First, check what loan_payment subcategories exist
-- Then update rules to use the first available one, or set a sensible default

-- For loan_payments, if no subcategory is specified, use credit_card_payment as default
-- (most common loan payment type)
UPDATE spendsense.merchant_rules
SET subcategory_code = 'credit_card_payment'
WHERE category_code = 'loan_payments'
  AND subcategory_code IS NULL
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'credit_card_payment' AND category_code = 'loan_payments');

-- For shopping, if no subcategory is specified, use 'amazon' as default
-- (the generic "Online Shopping" bucket)
UPDATE spendsense.merchant_rules
SET subcategory_code = 'amazon'
WHERE category_code = 'shopping'
  AND subcategory_code IS NULL
  AND active = true
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'amazon' AND category_code = 'shopping');

-- Update the enrichment pipeline to assign default subcategories when category is set but subcategory is NULL
-- This is done in the pipeline.py code, but we can also update existing enriched records

-- For existing loan_payments without subcategory, assign credit_card_payment
UPDATE spendsense.txn_enriched
SET subcategory_code = 'credit_card_payment'
WHERE category_code = 'loan_payments'
  AND subcategory_code IS NULL
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'credit_card_payment' AND category_code = 'loan_payments');

-- For existing shopping without subcategory, assign 'amazon' (generic online shopping)
UPDATE spendsense.txn_enriched
SET subcategory_code = 'amazon'
WHERE category_code = 'shopping'
  AND subcategory_code IS NULL
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'amazon' AND category_code = 'shopping');

COMMIT;

