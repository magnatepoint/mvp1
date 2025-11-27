-- ============================================================================
-- Add More Description-Based Rules for Common Patterns
-- These will catch transactions that don't match merchant-based rules
-- ============================================================================

BEGIN;

-- Hotels/Restaurants in description → food_dining/fd_fine
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 35, 'description', '\y(HOTEL|RESTAURANT|DINING|BIRYANI|TANDOORI|MESS)\y',
 'food_dining', 'fd_fine', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Pet clinic/vet in description → pets/pet_vaccine
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 30, 'description', '\y(PET\s*CLINIC|VET|VETERINARY|ANIMAL\s*HOSPITAL)\y',
 'pets', 'pet_vaccine', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Chicken/meat in description → groceries/groc_fv
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 40, 'description', '\y(CHICKEN|MEAT|MUTTON|FISH|EGG|EGGS)\y',
 'groceries', 'groc_fv', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Finance/loan/emi in description → loan_payments (generic)
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 25, 'description', '\y(FINANCE|LOAN|EMI|INSTALLMENT)\y',
 'loan_payments', NULL, true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- American Express (credit card) → could be shopping or transfer
-- Leave as default for now, user can categorize manually

COMMIT;

