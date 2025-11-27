-- ============================================================================
-- Fix Taxonomy Mappings and Add Description-Based Rules
-- 
-- This migration:
-- 1. Fixes remaining taxonomy mismatches (online_groceries → groc_online, etc.)
-- 2. Adds description-based rules for coffee/tea, vegetables, fuel
-- 3. Updates cafe rules to use food_dining/fd_cafes
-- ============================================================================

BEGIN;

-- ============================================================================
-- PART 1: Fix Remaining Taxonomy Mappings
-- ============================================================================

-- Quick commerce: groceries/online_groceries → groceries/groc_online
UPDATE spendsense.merchant_rules
SET subcategory_code = 'groc_online'
WHERE category_code = 'groceries'
  AND subcategory_code = 'online_groceries'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'groc_online' AND category_code = 'groceries');

-- Migrate existing enriched data: online_groceries → groc_online
UPDATE spendsense.txn_enriched
SET subcategory_code = 'groc_online'
WHERE category_code = 'groceries'
  AND subcategory_code = 'online_groceries'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'groc_online' AND category_code = 'groceries');

-- Cafes: dining/cafes_bistros → food_dining/fd_cafes
UPDATE spendsense.merchant_rules
SET category_code = 'food_dining',
    subcategory_code = 'fd_cafes'
WHERE category_code = 'dining'
  AND subcategory_code = 'cafes_bistros'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_cafes' AND category_code = 'food_dining');

-- Migrate existing enriched data: cafes_bistros → fd_cafes
UPDATE spendsense.txn_enriched
SET category_code = 'food_dining',
    subcategory_code = 'fd_cafes'
WHERE category_code = 'dining'
  AND subcategory_code = 'cafes_bistros'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_cafes' AND category_code = 'food_dining');

-- ============================================================================
-- PART 2: Add Description-Based Rules for Common Patterns
-- ============================================================================

-- Coffee/Tea in description → food_dining/fd_cafes
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 40, 'description',
 '(?i)\b(COFFEE|CAPPUCCINO|LATTE|ESPRESSO|CAF[EÉ]|TEA|CHAI|MASALA\s*CHAI|GREEN\s*TEA|BLACK\s*TEA)\b',
 'food_dining', 'fd_cafes', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Vegetables/Fruits in description → groceries/groc_fv
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 45, 'description',
 '(?i)\b(POTATO(?:ES)?|CARROT(?:S)?|TOMATO(?:ES)?|ONION(?:S)?|VEGETABLES?|FRUIT(?:S)?|GREEN(?:S)?|SABZI|SABJI|BHINDI|BRINJAL|CABBAGE|CAULIFLOWER|BEANS|PEAS|CORN|APPLE|BANANA|ORANGE|MANGO|GRAPES)\b',
 'groceries', 'groc_fv', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Fuel keywords in description → motor_maintenance/automotive_services
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 30, 'description',
 '(?i)\b(FUEL|PETROL|DIESEL|DISEL|GASOLINE|GAS\s*FILL|REFUEL)\b',
 'motor_maintenance', 'automotive_services', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- BP (British Petroleum) as merchant → motor_maintenance/automotive_services
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 26, 'merchant',
 '(?i)^BP$|^(BP\s*CL|BPCL)$',
 'motor_maintenance', 'automotive_services', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Rent/Housing payments in description → housing_fixed/house_rent
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 25, 'description',
 '(?i)\b(RENT|HOUSE\s*RENT|MONTHLY\s*RENT|ROOM\s*RENT|APARTMENT\s*RENT)\b',
 'housing_fixed', 'house_rent', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Maid/House help in description → housing_fixed/house_maid
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 28, 'description',
 '(?i)\b(MAID|HOUSE\s*HELP|HOUSE\s*KEEPER|COOK|CLEANER|DOMESTIC\s*HELP|MONTHLY\s*PAYMENT.*MAID)\b',
 'housing_fixed', 'house_maid', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- PART 3: Clean up any remaining invalid codes
-- ============================================================================

-- Set subcategory to NULL where it doesn't exist
UPDATE spendsense.merchant_rules
SET subcategory_code = NULL,
    notes = COALESCE(notes || '; ', '') || 'Subcategory code does not exist, set to NULL'
WHERE subcategory_code IS NOT NULL
  AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory);

-- Deactivate rules with invalid category codes
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: category_code does not exist'
WHERE category_code IS NOT NULL
  AND category_code NOT IN (SELECT category_code FROM spendsense.dim_category);

-- Clean up enriched data with invalid subcategory codes
UPDATE spendsense.txn_enriched
SET subcategory_code = NULL
WHERE subcategory_code IS NOT NULL
  AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory);

COMMIT;

