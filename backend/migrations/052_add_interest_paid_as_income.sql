-- ============================================================================
-- Migration 052: Add Interest Paid as Income Rule
-- 
-- Categorizes "Interest Paid" transactions as income (not banks/fees)
-- This rule has higher priority than the existing banks rule to take precedence
-- ============================================================================

BEGIN;

SET search_path TO spendsense, public, extensions;

-- Add rule for Interest Paid as income (priority 10 - higher than banks rule at 20)
-- This will match "Interest Paid Till 30-Sep-2025" and similar patterns
INSERT INTO spendsense.merchant_rules (
    rule_id, 
    priority, 
    applies_to, 
    pattern_regex, 
    category_code, 
    subcategory_code, 
    active, 
    source, 
    tenant_id, 
    created_by,
    pattern_hash,
    notes
)
VALUES
    (
        gen_random_uuid(), 
        10, 
        'description', 
        '(?i)\binterest\s+paid\b', 
        'income', 
        'inc_interest', 
        true, 
        'seed', 
        NULL, 
        NULL,
        encode(digest('(?i)\binterest\s+paid\b', 'sha1'), 'hex'),
        'Interest Paid - categorize as income, not banks'
    )
ON CONFLICT DO NOTHING;

-- Also add a merchant rule in case it appears in merchant name
INSERT INTO spendsense.merchant_rules (
    rule_id, 
    priority, 
    applies_to, 
    pattern_regex, 
    category_code, 
    subcategory_code, 
    active, 
    source, 
    tenant_id, 
    created_by,
    pattern_hash,
    notes
)
VALUES
    (
        gen_random_uuid(), 
        10, 
        'merchant', 
        '(?i)\binterest\s+paid\b', 
        'income', 
        'inc_interest', 
        true, 
        'seed', 
        NULL, 
        NULL,
        encode(digest('(?i)\binterest\s+paid\b', 'sha1'), 'hex'),
        'Interest Paid - categorize as income, not banks'
    )
ON CONFLICT DO NOTHING;

COMMIT;

