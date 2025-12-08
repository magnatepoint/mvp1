-- ============================================================================
-- Migration 049: Add Additional Merchants
-- 
-- Adds merchants based on user feedback:
-- - Quadrillion Finance (personal loan EMI)
-- - Personal names (P2P transfers)
-- - Orange Auto Private (car servicing)
-- - Congressional The Be (apparel)
-- - United Blowpast Cont (business expense)
-- - Comfy (pet)
-- - Icclgroww (SIP investment)
-- - Idfc First Bank (credit card payment)
-- - Shivi Sree Milk Poin (pan shop)
-- - Bhdfu4f0h84ogq/Billdkhdfccard (credit card payment)
-- ============================================================================

BEGIN;

SET search_path TO spendsense, public, extensions;

-- ============================================================================
-- 1) Add merchants to dim_merchant
-- ============================================================================

INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
    -- Quadrillion Finance - Personal Loan EMI
    ('quadrillion_finance', 'Quadrillion Finance', 'quadrillion finance',
     ARRAY['quadrillion','quadrillion finance','quadrillionfin'],
     'loans_payments', 'loan_personal', 'finance', NULL),
    
    -- Orange Auto Private - Car Servicing
    ('orange_auto', 'Orange Auto Private', 'orange auto private',
     ARRAY['orange auto','orange auto private','orangeauto'],
     'motor_maintenance', 'motor_services', 'automotive', NULL),
    
    -- Congressional The Be - Apparel
    ('congressional', 'Congressional The Be', 'congressional the be',
     ARRAY['congressional','congressional the be','congressionalthebe'],
     'shopping', 'shop_clothing', 'retail', NULL),
    
    -- United Blowpast Cont - Business Expense
    ('united_blowpast', 'United Blowpast Cont', 'united blowpast cont',
     ARRAY['united blowpast','united blowpast cont','unitedblowpast'],
     'business_expenses', 'biz_other', 'business', NULL),
    
    -- Comfy - Pet
    ('comfy', 'Comfy', 'comfy',
     ARRAY['comfy'],
     'pets', 'pet_grooming', 'retail', NULL),
    
    -- Icclgroww - SIP Investment
    ('icclgroww', 'Icclgroww', 'icclgroww',
     ARRAY['icclgroww','iccl groww','groww'],
     'investments_commitments', 'inv_sip', 'finance', NULL),
    
    -- Idfc First Bank - Credit Card Payment
    ('idfc_first', 'IDFC First Bank', 'idfc first bank',
     ARRAY['idfc first','idfc first bank','idfcfirst','idfc'],
     'loans_payments', 'loan_cc_bill', 'banks', 'https://www.idfcfirstbank.com'),
    
    -- Shivi Sree Milk Poin - Pan Shop
    ('shivi_sree', 'Shivi Sree Milk Poin', 'shivi sree milk poin',
     ARRAY['shivi sree','shivi sree milk poin','shivisree'],
     'food_dining', 'fd_pan_shop', 'retail', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- ============================================================================
-- 2) Add merchant rules for pattern matching
-- ============================================================================

INSERT INTO spendsense.merchant_rules (
    rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code,
    active, source, tenant_id, created_by, created_at
)
VALUES
    -- Quadrillion Finance
    (gen_random_uuid(), 15, 'merchant', '\bquadrillion\b', 'loans_payments', 'loan_personal', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 15, 'description', '\bquadrillion\b', 'loans_payments', 'loan_personal', true, 'seed', NULL, NULL, now()),
    
    -- Orange Auto Private
    (gen_random_uuid(), 15, 'merchant', '\borange\s*auto\b', 'motor_maintenance', 'motor_services', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 15, 'description', '\borange\s*auto\b', 'motor_maintenance', 'motor_services', true, 'seed', NULL, NULL, now()),
    
    -- Congressional The Be
    (gen_random_uuid(), 15, 'merchant', '\bcongressional\b', 'shopping', 'shop_clothing', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 15, 'description', '\bcongressional\b', 'shopping', 'shop_clothing', true, 'seed', NULL, NULL, now()),
    
    -- United Blowpast Cont
    (gen_random_uuid(), 15, 'merchant', '\bunited\s*blowpast\b', 'business_expenses', 'biz_other', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 15, 'description', '\bunited\s*blowpast\b', 'business_expenses', 'biz_other', true, 'seed', NULL, NULL, now()),
    
    -- Comfy
    (gen_random_uuid(), 15, 'merchant', '\bcomfy\b', 'pets', 'pet_grooming', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 15, 'description', '\bcomfy\b', 'pets', 'pet_grooming', true, 'seed', NULL, NULL, now()),
    
    -- Icclgroww / Groww
    (gen_random_uuid(), 15, 'merchant', '\b(icclgroww|groww)\b', 'investments_commitments', 'inv_sip', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 15, 'description', '\b(icclgroww|groww)\b', 'investments_commitments', 'inv_sip', true, 'seed', NULL, NULL, now()),
    
    -- Idfc First Bank - Credit Card Payment
    (gen_random_uuid(), 12, 'merchant', '\bidfc\s*first\b', 'loans_payments', 'loan_cc_bill', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 12, 'description', '\bidfc\s*first\b', 'loans_payments', 'loan_cc_bill', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 12, 'description', '\bidfcfirst\b', 'loans_payments', 'loan_cc_bill', true, 'seed', NULL, NULL, now()),
    
    -- Shivi Sree Milk Poin
    (gen_random_uuid(), 15, 'merchant', '\bshivi\s*sree\b', 'food_dining', 'fd_pan_shop', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 15, 'description', '\bshivi\s*sree\b', 'food_dining', 'fd_pan_shop', true, 'seed', NULL, NULL, now()),
    
    -- Billdkhdfccard / Bhdfu4f0h84ogq - Credit Card Payment
    (gen_random_uuid(), 10, 'description', '\bbilldkhdfccard\b', 'loans_payments', 'loan_cc_bill', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 10, 'description', '\bbhdfu4f0h84ogq\b', 'loans_payments', 'loan_cc_bill', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 10, 'description', '\bbill.*hdfc.*card\b', 'loans_payments', 'loan_cc_bill', true, 'seed', NULL, NULL, now()),
    
    -- Personal Names - P2P Transfers (for debits)
    (gen_random_uuid(), 8, 'merchant', '\bg\s*vijay\s*kumar\s*goud\b', 'transfers_out', 'tr_out_wallet', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 8, 'merchant', '\bg\s*ravi\b', 'transfers_out', 'tr_out_wallet', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 8, 'merchant', '\bgollagudem\s*ravi\b', 'transfers_out', 'tr_out_wallet', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 8, 'merchant', '\bm\s*s\s*s\s*ravi\s*babu\b', 'transfers_out', 'tr_out_wallet', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 8, 'description', '\bg\s*vijay\s*kumar\s*goud\b', 'transfers_out', 'tr_out_wallet', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 8, 'description', '\bg\s*ravi\b', 'transfers_out', 'tr_out_wallet', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 8, 'description', '\bgollagudem\s*ravi\b', 'transfers_out', 'tr_out_wallet', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 8, 'description', '\bm\s*s\s*s\s*ravi\s*babu\b', 'transfers_out', 'tr_out_wallet', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 3) Create merchant aliases for better matching
-- ============================================================================

INSERT INTO spendsense.merchant_alias (merchant_id, alias, normalized_alias)
SELECT 
    dm.merchant_id,
    unnest(dm.brand_keywords),
    lower(regexp_replace(unnest(dm.brand_keywords), '[^a-z0-9]', '', 'g'))
FROM spendsense.dim_merchant dm
WHERE dm.merchant_code IN (
    'quadrillion_finance',
    'orange_auto',
    'congressional',
    'united_blowpast',
    'comfy',
    'icclgroww',
    'idfc_first',
    'shivi_sree'
)
ON CONFLICT (merchant_id, normalized_alias) DO NOTHING;

COMMIT;


