-- ============================================================================
-- Migration 045: Add Magnatepoint Pvt Ltd as Income/Salary Merchant
-- 
-- Fixes transactions incorrectly showing as "Hdfc Bank" when they're actually
-- salary credits from Magnatepoint Pvt Ltd. Sets correct category: income/inc_salary
-- ============================================================================

BEGIN;

SET search_path TO spendsense, public, extensions;

-- ============================================================================
-- 1. Add Magnatepoint Pvt Ltd to dim_merchant table
-- ============================================================================

INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('magnatepoint', 'Magnatepoint Pvt Ltd', 'magnatepoint pvt ltd', 
 ARRAY['magnatepoint','magnatepoint pvt ltd','magnatepoint private limited','magnatepoint pvt','magnatepoint pvt ltd'],
 'income', 'inc_salary', 'finance', NULL)
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
-- 2. Add merchant rules with high priority (priority 15)
-- Higher priority ensures it matches before generic bank rules
-- ============================================================================

INSERT INTO spendsense.merchant_rules (
    rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, 
    active, source, tenant_id, created_by, created_at
)
VALUES 
    -- High priority rule for merchant name matching
    -- PostgreSQL ~* operator is case-insensitive, so no need for (?i) flag
    -- Matches: "MAGNATEPOINT", "Magnatepoint", "magnatepoint", "MAGNATEPOINT TECHNOLOGIES", etc.
    (gen_random_uuid(), 15, 'merchant', '\ymagnatepoint\y', 'income', 'inc_salary', true, 'seed', NULL, NULL, now()),
    -- Also match on description (in case merchant name is not parsed correctly)
    -- Simple pattern that matches anywhere in description (case-insensitive via ~*)
    (gen_random_uuid(), 14, 'description', 'magnatepoint', 'income', 'inc_salary', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

COMMENT ON TABLE spendsense.dim_merchant IS 'Merchant master data - updated to include Magnatepoint Pvt Ltd as income/salary';

COMMIT;

-- ============================================================================
-- After running this migration, re-enrich affected transactions:
-- 
-- python3 -m app.spendsense.scripts.re_enrich_user <user_id>
-- 
-- Or re-enrich all transactions for all users:
-- python3 -m app.spendsense.scripts.backfill_parse_and_enrich --all-users
-- ============================================================================

