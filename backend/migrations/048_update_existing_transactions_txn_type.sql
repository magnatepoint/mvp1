-- ============================================================================
-- Migration 048: Update Existing Transactions to New txn_types
-- 
-- Updates user overrides and ensures all transactions reflect the new
-- txn_type mappings (loans_payments → debt, insurance_premiums → protection)
-- ============================================================================

BEGIN;

SET search_path TO spendsense, public;

-- ============================================================================
-- 1) Update user overrides for remapped categories
-- ============================================================================

-- Update loans_payments overrides: if txn_type was 'needs', change to 'debt'
-- (preserve other overrides like 'income' if user explicitly set them)
UPDATE spendsense.txn_override
SET txn_type = 'debt'
WHERE category_code = 'loans_payments'
  AND txn_type = 'needs';

-- Update insurance_premiums overrides: if txn_type was 'needs', change to 'protection'
UPDATE spendsense.txn_override
SET txn_type = 'protection'
WHERE category_code = 'insurance_premiums'
  AND txn_type = 'needs';

-- ============================================================================
-- 2) Verify the view is working correctly
-- ============================================================================

-- The vw_txn_effective view already handles the new txn_types correctly
-- because it looks up dim_category.txn_type, which we've already updated.
-- This migration just ensures user overrides are consistent.

COMMIT;

-- ============================================================================
-- Migration complete
-- ============================================================================
-- Summary:
-- 1. Updated user overrides for loans_payments (needs → debt)
-- 2. Updated user overrides for insurance_premiums (needs → protection)
-- 3. All transactions will now show correct txn_types through vw_txn_effective
-- ============================================================================

