-- ============================================================================
-- Deactivate Old Taxonomy Rules
-- Deactivate rules using old taxonomy codes (dining/zomato, etc.)
-- These are replaced by new rules with correct taxonomy (food_dining/fd_online, etc.)
-- ============================================================================

BEGIN;

-- Deactivate old dining/zomato rules (replaced by food_dining/fd_online)
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: replaced by food_dining/fd_online rules'
WHERE category_code = 'dining'
  AND subcategory_code = 'zomato'
  AND active = true;

-- Deactivate old dining/online_delivery rules if they exist (replaced by food_dining/fd_online)
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: replaced by food_dining/fd_online rules'
WHERE category_code = 'dining'
  AND subcategory_code = 'online_delivery'
  AND active = true;

-- Deactivate old dining/cafes_bistros rules (replaced by food_dining/fd_cafes)
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: replaced by food_dining/fd_cafes rules'
WHERE category_code = 'dining'
  AND subcategory_code = 'cafes_bistros'
  AND active = true;

-- Deactivate old groceries/online_groceries rules (replaced by groceries/groc_online)
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: replaced by groceries/groc_online rules'
WHERE category_code = 'groceries'
  AND subcategory_code = 'online_groceries'
  AND active = true;

-- Deactivate old groceries/supermarkets rules (replaced by groceries/groc_hyper)
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: replaced by groceries/groc_hyper rules'
WHERE category_code = 'groceries'
  AND subcategory_code = 'supermarkets'
  AND active = true;

COMMIT;

