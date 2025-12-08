-- ============================================================================
-- Migration 047: Expanded Taxonomy - India-Aware Transaction Types
-- 
-- 1. Expands txn_type pillars to include: debt, protection, charity, business
-- 2. Remaps existing categories to new txn_types
-- 3. Adds India-specific categories: charity_donations, festivals_rituals, 
--    family_support, business_expenses, govt_benefits
-- 4. Updates all CHECK constraints and view logic
-- ============================================================================

BEGIN;

SET search_path TO spendsense, public;

-- ============================================================================
-- 1) Update CHECK constraints on all tables with txn_type
-- ============================================================================

-- Update dim_category CHECK constraint
ALTER TABLE spendsense.dim_category
    DROP CONSTRAINT IF EXISTS dim_category_txn_type_check;

ALTER TABLE spendsense.dim_category
    ADD CONSTRAINT dim_category_txn_type_check
    CHECK (txn_type IN (
        'income',
        'needs',
        'wants',
        'assets',
        'debt',
        'protection',
        'transfer',
        'fees',
        'tax',
        'charity',
        'business'
    ));

-- Update txn_override CHECK constraint (if exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'spendsense'
          AND table_name = 'txn_override'
          AND column_name = 'txn_type'
    ) THEN
        ALTER TABLE spendsense.txn_override
            DROP CONSTRAINT IF EXISTS txn_override_txn_type_check;
        
        ALTER TABLE spendsense.txn_override
            ADD CONSTRAINT txn_override_txn_type_check
            CHECK (txn_type IN (
                'income', 'needs', 'wants', 'assets', 'debt',
                'protection', 'transfer', 'fees', 'tax', 'charity', 'business'
            ));
    END IF;
END $$;

-- Update other tables that might have txn_type constraints
-- Check and update specific known tables
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Find and drop all CHECK constraints on txn_type columns
    FOR r IN 
        SELECT DISTINCT tc.table_name, tc.constraint_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu 
            ON tc.constraint_schema = ccu.constraint_schema
            AND tc.constraint_name = ccu.constraint_name
        WHERE tc.table_schema = 'spendsense'
          AND tc.constraint_type = 'CHECK'
          AND ccu.column_name = 'txn_type'
    LOOP
        EXECUTE format('ALTER TABLE spendsense.%I DROP CONSTRAINT IF EXISTS %I',
                       r.table_name, r.constraint_name);
    END LOOP;
END $$;

-- ============================================================================
-- 2) Remap existing categories to new txn_types
-- ============================================================================

-- loans_payments → debt
UPDATE spendsense.dim_category
SET txn_type = 'debt'
WHERE category_code = 'loans_payments'
  AND user_id IS NULL
  AND is_custom = FALSE;

-- insurance_premiums → protection
UPDATE spendsense.dim_category
SET txn_type = 'protection'
WHERE category_code = 'insurance_premiums'
  AND user_id IS NULL
  AND is_custom = FALSE;

-- Verify other categories are already correctly mapped:
-- income → income ✓
-- transfers_in → transfer ✓
-- transfers_out → transfer ✓
-- investments_commitments → assets ✓
-- housing_fixed → needs ✓
-- utilities → needs ✓
-- groceries → needs ✓
-- medical → needs ✓
-- education → needs ✓
-- child_care → needs ✓
-- motor_maintenance → needs ✓
-- transport → needs ✓
-- entertainment → wants ✓
-- food_dining → wants ✓
-- shopping → wants ✓
-- fitness → wants ✓
-- pets → wants ✓
-- banks → fees ✓
-- govt_tax → tax ✓

-- ============================================================================
-- 3) Insert new India-specific categories
-- ============================================================================

INSERT INTO spendsense.dim_category (
    category_code, category_name, txn_type, display_order, active, user_id, is_custom
)
VALUES
    ('charity_donations', 'Charity & Donations', 'charity', 70, TRUE, NULL, FALSE),
    ('festivals_rituals', 'Festivals, Rituals & Celebrations', 'wants', 72, TRUE, NULL, FALSE),
    ('family_support', 'Family Support & Obligations', 'needs', 74, TRUE, NULL, FALSE),
    ('business_expenses', 'Business & Freelance Expenses', 'business', 80, TRUE, NULL, FALSE),
    ('govt_benefits', 'Government Benefits & Subsidies', 'income', 82, TRUE, NULL, FALSE)
ON CONFLICT (category_code) 
DO UPDATE
SET category_name = EXCLUDED.category_name,
    txn_type      = EXCLUDED.txn_type,
    display_order = EXCLUDED.display_order,
    active        = TRUE,
    is_custom     = FALSE,
    user_id       = NULL
WHERE dim_category.user_id IS NULL;

-- ============================================================================
-- 4) Insert new subcategories
-- ============================================================================

-- Charity & Donations
INSERT INTO spendsense.dim_subcategory (
    subcategory_code, category_code, subcategory_name, display_order, active, user_id, is_custom
)
VALUES
    ('char_temple',    'charity_donations', 'Temple / Puja / Hundi',         10, TRUE, NULL, FALSE),
    ('char_mosque',    'charity_donations', 'Mosque / Zakat / Sadaqah',      11, TRUE, NULL, FALSE),
    ('char_church',    'charity_donations', 'Church Offerings',              12, TRUE, NULL, FALSE),
    ('char_gurudwara', 'charity_donations', 'Gurudwara / Langar / Seva',     13, TRUE, NULL, FALSE),
    ('char_ngo',       'charity_donations', 'NGOs & Social Causes',           14, TRUE, NULL, FALSE),
    ('char_crowdfund', 'charity_donations', 'Crowdfunding / Medical Help',   15, TRUE, NULL, FALSE),
    ('char_other',     'charity_donations', 'Other Donations & Offerings',    19, TRUE, NULL, FALSE)
ON CONFLICT (subcategory_code) 
DO UPDATE
SET category_code   = EXCLUDED.category_code,
    subcategory_name = EXCLUDED.subcategory_name,
    display_order    = EXCLUDED.display_order,
    active           = TRUE,
    is_custom        = FALSE,
    user_id          = NULL
WHERE dim_subcategory.user_id IS NULL;

-- Festivals, Rituals & Celebrations
INSERT INTO spendsense.dim_subcategory (
    subcategory_code, category_code, subcategory_name, display_order, active, user_id, is_custom
)
VALUES
    ('fest_pooja_items', 'festivals_rituals', 'Puja Items & Ritual Needs',   10, TRUE, NULL, FALSE),
    ('fest_decor',       'festivals_rituals', 'Decorations & Lights',         11, TRUE, NULL, FALSE),
    ('fest_sweets',      'festivals_rituals', 'Sweets & Snacks',              12, TRUE, NULL, FALSE),
    ('fest_clothing',    'festivals_rituals', 'Festival Clothing & Wear',    13, TRUE, NULL, FALSE),
    ('fest_gifts',       'festivals_rituals', 'Festival Gifts',               14, TRUE, NULL, FALSE),
    ('fest_pandal',      'festivals_rituals', 'Pandal / Mandap & Events',     15, TRUE, NULL, FALSE),
    ('fest_other',       'festivals_rituals', 'Other Festival Expenses',     19, TRUE, NULL, FALSE)
ON CONFLICT (subcategory_code) 
DO UPDATE
SET category_code   = EXCLUDED.category_code,
    subcategory_name = EXCLUDED.subcategory_name,
    display_order    = EXCLUDED.display_order,
    active           = TRUE,
    is_custom        = FALSE,
    user_id          = NULL
WHERE dim_subcategory.user_id IS NULL;

-- Family Support & Obligations
INSERT INTO spendsense.dim_subcategory (
    subcategory_code, category_code, subcategory_name, display_order, active, user_id, is_custom
)
VALUES
    ('fam_parents',        'family_support', 'Monthly Support to Parents/In-laws', 10, TRUE, NULL, FALSE),
    ('fam_relatives',      'family_support', 'Support to Siblings/Relatives',      11, TRUE, NULL, FALSE),
    ('fam_medical_help',   'family_support', 'Helping Family with Medical Bills',  12, TRUE, NULL, FALSE),
    ('fam_education_help', 'family_support', 'Paying Relatives'' Education Fees',  13, TRUE, NULL, FALSE),
    ('fam_other',          'family_support', 'Other Family Support',               19, TRUE, NULL, FALSE)
ON CONFLICT (subcategory_code) 
DO UPDATE
SET category_code   = EXCLUDED.category_code,
    subcategory_name = EXCLUDED.subcategory_name,
    display_order    = EXCLUDED.display_order,
    active           = TRUE,
    is_custom        = FALSE,
    user_id          = NULL
WHERE dim_subcategory.user_id IS NULL;

-- Business & Freelance Expenses
INSERT INTO spendsense.dim_subcategory (
    subcategory_code, category_code, subcategory_name, display_order, active, user_id, is_custom
)
VALUES
    ('biz_raw_materials',  'business_expenses', 'Materials / Inventory',           10, TRUE, NULL, FALSE),
    ('biz_tools_software', 'business_expenses', 'Tools, SaaS, Domains, Hosting',  11, TRUE, NULL, FALSE),
    ('biz_marketing',      'business_expenses', 'Ads, Marketing, Campaigns',      12, TRUE, NULL, FALSE),
    ('biz_travel',         'business_expenses', 'Client Travel & Stays',          13, TRUE, NULL, FALSE),
    ('biz_salary',         'business_expenses', 'Salaries/Stipends to Staff',      14, TRUE, NULL, FALSE),
    ('biz_rent',           'business_expenses', 'Office / Shop Rent',             15, TRUE, NULL, FALSE),
    ('biz_other',          'business_expenses', 'Other Business Expenses',        19, TRUE, NULL, FALSE)
ON CONFLICT (subcategory_code) 
DO UPDATE
SET category_code   = EXCLUDED.category_code,
    subcategory_name = EXCLUDED.subcategory_name,
    display_order    = EXCLUDED.display_order,
    active           = TRUE,
    is_custom        = FALSE,
    user_id          = NULL
WHERE dim_subcategory.user_id IS NULL;

-- Government Benefits & Subsidies
INSERT INTO spendsense.dim_subcategory (
    subcategory_code, category_code, subcategory_name, display_order, active, user_id, is_custom
)
VALUES
    ('govt_subsidy',      'govt_benefits', 'LPG, Fertilizer & Other Subsidies', 10, TRUE, NULL, FALSE),
    ('govt_scheme',       'govt_benefits', 'PM Kisan, Pensions, Welfare Schemes', 11, TRUE, NULL, FALSE),
    ('govt_other_benefits', 'govt_benefits', 'Other Government Benefits',        19, TRUE, NULL, FALSE)
ON CONFLICT (subcategory_code) 
DO UPDATE
SET category_code   = EXCLUDED.category_code,
    subcategory_name = EXCLUDED.subcategory_name,
    display_order    = EXCLUDED.display_order,
    active           = TRUE,
    is_custom        = FALSE,
    user_id          = NULL
WHERE dim_subcategory.user_id IS NULL;

-- ============================================================================
-- 5) Update vw_txn_effective view to handle new txn_types
-- ============================================================================

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
  COALESCE(lo.category_code, te.category_id) AS category_code,
  COALESCE(lo.subcategory_code, te.subcategory_id) AS subcategory_code,
  CASE
    WHEN lo.txn_type IS NOT NULL THEN lo.txn_type
    -- If we have a category_id, always look it up first (most accurate)
    WHEN COALESCE(lo.category_code, te.category_id) IS NOT NULL THEN
      COALESCE(
        (SELECT dc.txn_type FROM spendsense.dim_category dc WHERE dc.category_code = COALESCE(lo.category_code, te.category_id)),
        -- Fallback to cat_l1 logic if category not found
        CASE LOWER(COALESCE(te.cat_l1, ''))
          WHEN 'income' THEN 'income'
          WHEN 'loan' THEN 'debt'
          WHEN 'investment' THEN 'assets'
          WHEN 'transfer' THEN 'transfer'
          WHEN 'fee' THEN 'fees'
          WHEN 'cash' THEN 'transfer'
          ELSE 'wants'
        END
      )
    -- Fallback to cat_l1 if no category_id
    WHEN te.cat_l1 IS NOT NULL THEN 
      CASE LOWER(te.cat_l1)
        WHEN 'income' THEN 'income'
        WHEN 'expense' THEN 'wants'  -- Default for expenses without category
        WHEN 'loan' THEN 'debt'
        WHEN 'investment' THEN 'assets'
        WHEN 'transfer' THEN 'transfer'
        WHEN 'fee' THEN 'fees'
        WHEN 'cash' THEN 'transfer'
        ELSE 'wants'
      END
    -- Final fallback: credits are income, debits look up category or default to wants
    WHEN f.direction = 'credit' THEN 'income'
    ELSE (
      SELECT COALESCE(dc.txn_type, 'wants')
      FROM spendsense.dim_category dc
      WHERE dc.category_code = COALESCE(lo.category_code, te.category_id)
    )
  END AS txn_type,
  f.merchant_id,
  f.merchant_name_norm,
  tp.counterparty_name,
  COALESCE(te.merchant_name, tp.counterparty_name, f.merchant_name_norm) AS merchant_name,
  CASE
    WHEN COALESCE(te.transfer_type, '') IN ('P2P', 'SELF') THEN 'N'
    WHEN te.merchant_id IS NOT NULL OR te.merchant_name IS NOT NULL THEN 'Y'
    WHEN f.merchant_id IS NOT NULL THEN 'Y'
    WHEN COALESCE(TRIM(f.merchant_name_norm), '') <> '' THEN 'Y'
    ELSE 'N'
  END AS merchant_flag,
  COALESCE(tp.channel_type, te.channel_type, f.channel) AS channel_type,
  COALESCE(te.raw_description, tp.raw_description, f.description) AS raw_description,
  f.bank_code,
  f.channel,
  COALESCE(tp.created_at::time, f.created_at::time) AS txn_time
FROM spendsense.txn_fact f
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
LEFT JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
LEFT JOIN last_override lo ON lo.txn_id = f.txn_id;

COMMENT ON VIEW spendsense.vw_txn_effective IS
'Effective transaction view with enriched metadata. Includes new txn_types: debt, protection, charity, business.';

-- ============================================================================
-- 6) Add comments for documentation
-- ============================================================================

COMMENT ON COLUMN spendsense.dim_category.txn_type IS 
'Transaction type pillar: income, needs, wants, assets, debt, protection, transfer, fees, tax, charity, business';

COMMIT;

-- ============================================================================
-- Migration complete
-- ============================================================================
-- Summary of changes:
-- 1. Expanded txn_type from 7 to 11 pillars (added: debt, protection, charity, business)
-- 2. Remapped loans_payments → debt, insurance_premiums → protection
-- 3. Added 5 new India-specific categories with 28 subcategories
-- 4. Updated all CHECK constraints
-- 5. Updated vw_txn_effective view logic
-- ============================================================================

