-- ============================================================================
-- Fix Merchant Rules Taxonomy Alignment
-- Updates merchant_rules to use subcategory codes that exist in dim_subcategory
-- Also migrates existing enriched data to use correct codes
-- 
-- This migration aligns merchant rules with the actual taxonomy in dim_subcategory
-- ============================================================================

BEGIN;

-- ============================================================================
-- PART 1: Fix Dining / Food Rules
-- ============================================================================

-- Food delivery: dining/online_delivery -> food_dining/fd_online
UPDATE spendsense.merchant_rules
SET category_code = 'food_dining',
    subcategory_code = 'fd_online'
WHERE category_code = 'dining'
  AND subcategory_code = 'online_delivery'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_online' AND category_code = 'food_dining');

-- Bars/Pubs: dining/pubs_bars -> food_dining/fd_pubs_bars
UPDATE spendsense.merchant_rules
SET category_code = 'food_dining',
    subcategory_code = 'fd_pubs_bars'
WHERE category_code = 'dining'
  AND subcategory_code = 'pubs_bars'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_pubs_bars' AND category_code = 'food_dining');

-- Street food: dining/street_food -> food_dining/fd_street_food
UPDATE spendsense.merchant_rules
SET category_code = 'food_dining',
    subcategory_code = 'fd_street_food'
WHERE category_code = 'dining'
  AND subcategory_code = 'street_food'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_street_food' AND category_code = 'food_dining');

-- Generic restaurants: keep dining/casual_dining (if it exists) or set to food_dining/fd_fine_dining
UPDATE spendsense.merchant_rules
SET category_code = 'food_dining',
    subcategory_code = COALESCE(
        (SELECT subcategory_code FROM spendsense.dim_subcategory 
         WHERE category_code = 'food_dining' AND subcategory_code = 'fd_fine_dining' LIMIT 1),
        NULL
    )
WHERE category_code = 'dining'
  AND subcategory_code = 'casual_dining'
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'casual_dining' AND category_code = 'dining');

-- Cafes: dining/cafes_bistros -> food_dining/fd_cafes_bistros (or keep if exists)
UPDATE spendsense.merchant_rules
SET category_code = 'food_dining',
    subcategory_code = COALESCE(
        (SELECT subcategory_code FROM spendsense.dim_subcategory 
         WHERE category_code = 'food_dining' AND subcategory_code IN ('fd_cafes_bistros', 'cafes_bistros') LIMIT 1),
        subcategory_code
    )
WHERE category_code = 'dining'
  AND subcategory_code = 'cafes_bistros'
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'cafes_bistros' AND category_code = 'dining');

-- ============================================================================
-- PART 2: Fix Groceries Rules
-- ============================================================================

-- DMART / big chains: groceries/supermarkets -> groceries/groc_hyper
UPDATE spendsense.merchant_rules
SET subcategory_code = 'groc_hyper'
WHERE category_code = 'groceries'
  AND subcategory_code = 'supermarkets'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'groc_hyper' AND category_code = 'groceries');

-- Quick commerce: groceries/online_groceries -> groceries/groc_online
UPDATE spendsense.merchant_rules
SET subcategory_code = 'groc_online'
WHERE category_code = 'groceries'
  AND subcategory_code = 'online_groceries'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'groc_online' AND category_code = 'groceries');

-- Kirana stores: groceries/mom_and_pop -> groceries/groc_fv
UPDATE spendsense.merchant_rules
SET subcategory_code = 'groc_fv'
WHERE category_code = 'groceries'
  AND subcategory_code = 'mom_and_pop'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'groc_fv' AND category_code = 'groceries');

-- ============================================================================
-- PART 3: Fix Shopping / Ecommerce
-- ============================================================================

-- Online shopping: shopping/online_shopping -> shopping/amazon (or keep online_shopping if exists)
UPDATE spendsense.merchant_rules
SET subcategory_code = COALESCE(
        (SELECT subcategory_code FROM spendsense.dim_subcategory 
         WHERE category_code = 'shopping' AND subcategory_code = 'amazon' LIMIT 1),
        (SELECT subcategory_code FROM spendsense.dim_subcategory 
         WHERE category_code = 'shopping' AND subcategory_code = 'online_shopping' LIMIT 1),
        NULL
    )
WHERE category_code = 'shopping'
  AND subcategory_code = 'online_shopping'
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'online_shopping' AND category_code = 'shopping');

-- ============================================================================
-- PART 4: Fix Income Rules
-- ============================================================================

-- Salary: income/wages -> income/inc_salary
UPDATE spendsense.merchant_rules
SET subcategory_code = 'inc_salary'
WHERE category_code = 'income'
  AND subcategory_code = 'wages'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'inc_salary' AND category_code = 'income');

-- Refund/cashback: income/other_income -> income/inc_other
UPDATE spendsense.merchant_rules
SET subcategory_code = 'inc_other'
WHERE category_code = 'income'
  AND subcategory_code = 'other_income'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'inc_other' AND category_code = 'income');

-- ============================================================================
-- PART 5: Fix Loan / Fees Rules (Set to NULL if subcategory doesn't exist)
-- ============================================================================

-- Personal loan payment: remove non-existent subcategory
UPDATE spendsense.merchant_rules
SET subcategory_code = NULL
WHERE category_code = 'loan_payments'
  AND subcategory_code = 'personal_loan_payment'
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'personal_loan_payment' AND category_code = 'loan_payments');

-- Bank fees rule: remove non-existent other_bank_fees
UPDATE spendsense.merchant_rules
SET subcategory_code = NULL
WHERE category_code = 'bank_fees'
  AND subcategory_code = 'other_bank_fees'
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'other_bank_fees' AND category_code = 'bank_fees');

-- Tax payment: keep category only
UPDATE spendsense.merchant_rules
SET subcategory_code = NULL
WHERE category_code = 'government_and_non_profit'
  AND subcategory_code = 'tax_payment'
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'tax_payment' AND category_code = 'government_and_non_profit');

-- ============================================================================
-- PART 6: Fix Utilities / Medical (Set to NULL if subcategory doesn't exist)
-- ============================================================================

-- Utilities (mobile/internet): keep only category
UPDATE spendsense.merchant_rules
SET subcategory_code = NULL
WHERE category_code = 'utilities'
  AND subcategory_code IN ('mobile_telephone', 'internet_and_cable')
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = merchant_rules.subcategory_code AND category_code = 'utilities');

-- Medical: keep only category
UPDATE spendsense.merchant_rules
SET subcategory_code = NULL
WHERE category_code = 'medical'
  AND subcategory_code IN ('primary_care', 'pharmacies_and_supplements', 'other_medical')
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = merchant_rules.subcategory_code AND category_code = 'medical');

-- ============================================================================
-- PART 7: Deactivate Rules with Invalid Codes (Final cleanup)
-- ============================================================================

-- Deactivate rules where subcategory_code still doesn't exist
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: subcategory_code does not exist in dim_subcategory'
WHERE subcategory_code IS NOT NULL
  AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory);

-- Deactivate rules where category_code doesn't exist
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: category_code does not exist in dim_category'
WHERE category_code IS NOT NULL
  AND category_code NOT IN (SELECT category_code FROM spendsense.dim_category);

-- ============================================================================
-- PART 8: Migrate Existing Enriched Data (Legacy Codes)
-- ============================================================================

-- Zomato-style online food -> food_dining/fd_online
UPDATE spendsense.txn_enriched
SET category_code = 'food_dining',
    subcategory_code = 'fd_online'
WHERE category_code = 'dining'
  AND subcategory_code = 'zomato'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_online' AND category_code = 'food_dining');

-- Bars/pubs -> food_dining/fd_pubs_bars
UPDATE spendsense.txn_enriched
SET category_code = 'food_dining',
    subcategory_code = 'fd_pubs_bars'
WHERE category_code = 'dining'
  AND subcategory_code = 'pubs_bars'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_pubs_bars' AND category_code = 'food_dining');

-- Income other_income -> income/inc_other
UPDATE spendsense.txn_enriched
SET subcategory_code = 'inc_other'
WHERE category_code = 'income'
  AND subcategory_code = 'other_income'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'inc_other' AND category_code = 'income');

-- ============================================================================
-- PART 9: Clean up enriched rows with invalid subcategory codes
-- ============================================================================

-- Set subcategory_code to NULL where it doesn't exist in dim_subcategory
UPDATE spendsense.txn_enriched
SET subcategory_code = NULL
WHERE subcategory_code IS NOT NULL
  AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory);

-- ============================================================================
-- PART 10: Clean up enriched rows with invalid category codes
-- ============================================================================

-- Set category_code to 'shopping' (fallback) where it doesn't exist
UPDATE spendsense.txn_enriched
SET category_code = 'shopping',
    subcategory_code = NULL
WHERE category_code IS NOT NULL
  AND category_code NOT IN (SELECT category_code FROM spendsense.dim_category);

COMMIT;
