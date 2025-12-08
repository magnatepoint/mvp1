-- ============================================================================
-- Migration 051: Add General Pan Shop Rule
-- 
-- Adds a general rule to categorize any transaction with "pan" in the 
-- merchant name or description as "fd_pan_shop" (Pan / Cigarette Shop)
-- ============================================================================

BEGIN;

SET search_path TO spendsense, public, extensions;

-- Add general pan shop rule for merchant field
-- Priority 20 (higher than existing pan shop rules to catch more cases)
-- Pattern matches "pan" at word boundary (matches "pan", "panshop", "pan shop", etc.)
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
        20, 
        'merchant', 
        '(?i)\bpan', 
        'food_dining', 
        'fd_pan_shop', 
        true, 
        'seed', 
        NULL, 
        NULL,
        encode(digest('(?i)\bpan', 'sha1'), 'hex'),
        'General rule: match "pan" in merchant name (word boundary)'
    )
ON CONFLICT DO NOTHING;

-- Add general pan shop rule for description field
-- Priority 20 (higher than existing pan shop rules to catch more cases)
-- Pattern matches "pan" at word boundary (matches "pan", "panshop", "pan shop", etc.)
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
        20, 
        'description', 
        '(?i)\bpan', 
        'food_dining', 
        'fd_pan_shop', 
        true, 
        'seed', 
        NULL, 
        NULL,
        encode(digest('(?i)\bpan', 'sha1'), 'hex'),
        'General rule: match "pan" in description (word boundary)'
    )
ON CONFLICT DO NOTHING;

COMMIT;

