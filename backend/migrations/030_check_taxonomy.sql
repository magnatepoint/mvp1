-- ============================================================================
-- Taxonomy Diagnostic Script
-- Run this BEFORE migration 030_fix_merchant_rules_taxonomy.sql
-- to see what codes exist and what needs to be fixed
-- ============================================================================

-- ============================================================================
-- PART 1: List all subcategory codes that exist in dim_subcategory
-- ============================================================================

SELECT 
    '=== EXISTING SUBCATEGORIES ===' AS section;

SELECT 
    category_code,
    subcategory_code,
    subcategory_name,
    active
FROM spendsense.dim_subcategory
ORDER BY category_code, subcategory_code;

-- ============================================================================
-- PART 2: List all category codes that exist in dim_category
-- ============================================================================

SELECT 
    '=== EXISTING CATEGORIES ===' AS section;

SELECT 
    category_code,
    category_name,
    txn_type,
    active
FROM spendsense.dim_category
ORDER BY category_code;

-- ============================================================================
-- PART 3: Merchant rules with invalid subcategory codes
-- ============================================================================

SELECT 
    '=== MERCHANT RULES WITH INVALID SUBCATEGORY CODES ===' AS section;

SELECT 
    mr.rule_id,
    mr.priority,
    mr.pattern_regex,
    mr.category_code AS rule_category,
    mr.subcategory_code AS rule_subcategory,
    mr.active,
    CASE 
        WHEN mr.category_code NOT IN (SELECT category_code FROM spendsense.dim_category) 
            THEN 'INVALID CATEGORY'
        WHEN mr.subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory)
            THEN 'INVALID SUBCATEGORY'
        ELSE 'OK'
    END AS issue
FROM spendsense.merchant_rules mr
WHERE mr.active = true
  AND (
      mr.category_code NOT IN (SELECT category_code FROM spendsense.dim_category)
      OR (mr.subcategory_code IS NOT NULL 
          AND mr.subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory))
  )
ORDER BY mr.category_code, mr.subcategory_code;

-- ============================================================================
-- PART 4: Count of merchant rules by category/subcategory
-- ============================================================================

SELECT 
    '=== MERCHANT RULES SUMMARY ===' AS section;

SELECT 
    mr.category_code,
    mr.subcategory_code,
    COUNT(*) AS rule_count,
    COUNT(*) FILTER (WHERE mr.active) AS active_count,
    CASE 
        WHEN mr.category_code NOT IN (SELECT category_code FROM spendsense.dim_category) 
            THEN 'INVALID CATEGORY'
        WHEN mr.subcategory_code IS NOT NULL 
             AND mr.subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory)
            THEN 'INVALID SUBCATEGORY'
        ELSE 'VALID'
    END AS status
FROM spendsense.merchant_rules mr
GROUP BY mr.category_code, mr.subcategory_code
ORDER BY mr.category_code, mr.subcategory_code;

-- ============================================================================
-- PART 5: Enriched transactions with invalid codes
-- ============================================================================

SELECT 
    '=== ENRICHED TRANSACTIONS WITH INVALID CODES ===' AS section;

SELECT 
    e.category_code AS enriched_category,
    e.subcategory_code AS enriched_subcategory,
    COUNT(*) AS transaction_count,
    CASE 
        WHEN e.category_code NOT IN (SELECT category_code FROM spendsense.dim_category) 
            THEN 'INVALID CATEGORY'
        WHEN e.subcategory_code IS NOT NULL 
             AND e.subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory)
            THEN 'INVALID SUBCATEGORY'
        ELSE 'OK'
    END AS issue
FROM spendsense.txn_enriched e
WHERE (
    e.category_code NOT IN (SELECT category_code FROM spendsense.dim_category)
    OR (e.subcategory_code IS NOT NULL 
        AND e.subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory))
)
GROUP BY e.category_code, e.subcategory_code
ORDER BY transaction_count DESC;

-- ============================================================================
-- PART 6: Specific codes that merchant rules are trying to use
-- ============================================================================

SELECT 
    '=== MERCHANT RULES: CODES IN USE ===' AS section;

SELECT DISTINCT
    mr.category_code,
    mr.subcategory_code,
    CASE 
        WHEN mr.category_code IN (SELECT category_code FROM spendsense.dim_category) 
            THEN 'EXISTS'
        ELSE 'MISSING'
    END AS category_status,
    CASE 
        WHEN mr.subcategory_code IS NULL 
            THEN 'NULL'
        WHEN mr.subcategory_code IN (SELECT subcategory_code FROM spendsense.dim_subcategory)
            THEN 'EXISTS'
        ELSE 'MISSING'
    END AS subcategory_status
FROM spendsense.merchant_rules mr
WHERE mr.active = true
ORDER BY mr.category_code, mr.subcategory_code;

-- ============================================================================
-- PART 7: Summary statistics
-- ============================================================================

SELECT 
    '=== SUMMARY STATISTICS ===' AS section;

SELECT 
    (SELECT COUNT(*) FROM spendsense.merchant_rules WHERE active = true) AS total_active_rules,
    (SELECT COUNT(*) FROM spendsense.merchant_rules 
     WHERE active = true 
       AND category_code NOT IN (SELECT category_code FROM spendsense.dim_category)) AS rules_invalid_category,
    (SELECT COUNT(*) FROM spendsense.merchant_rules 
     WHERE active = true 
       AND subcategory_code IS NOT NULL
       AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory)) AS rules_invalid_subcategory,
    (SELECT COUNT(*) FROM spendsense.txn_enriched 
     WHERE category_code NOT IN (SELECT category_code FROM spendsense.dim_category)) AS enriched_invalid_category,
    (SELECT COUNT(*) FROM spendsense.txn_enriched 
     WHERE subcategory_code IS NOT NULL
       AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory)) AS enriched_invalid_subcategory;

