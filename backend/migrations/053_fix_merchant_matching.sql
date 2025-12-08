-- ============================================================================
-- Migration 053: Fix Merchant Matching for UPI Transactions
-- 
-- This script re-enriches transactions with improved merchant matching
-- that uses counterparty_name and fuzzy matching for dim_merchant
-- ============================================================================

BEGIN;

SET search_path TO spendsense, public, extensions;

-- Delete all enriched records to start fresh
DELETE FROM spendsense.txn_enriched;

-- Re-enrich with improved matching logic
-- This matches the logic in pipeline.py with fuzzy matching for dim_merchant
INSERT INTO spendsense.txn_enriched (
    parsed_id, bank_code, txn_date, amount, cr_dr, channel_type, direction,
    category_id, subcategory_id, cat_l1, rule_id, confidence, created_at
)
WITH candidates AS (
    SELECT 
        f.txn_id,
        f.user_id,
        f.description,
        f.merchant_name_norm,
        f.direction,
        tp.parsed_id,
        tp.bank_code,
        tp.txn_date,
        tp.amount,
        tp.cr_dr,
        tp.channel_type,
        tp.direction AS parsed_direction,
        tp.counterparty_name,
        COALESCE(
            NULLIF(LOWER(TRIM(f.merchant_name_norm)), ''),
            NULLIF(LOWER(TRIM(tp.counterparty_name)), ''),
            LOWER(TRIM(f.description))
        ) AS merchant_for_matching
    FROM spendsense.txn_fact f
    JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
),
merchant_matches AS (
    WITH regex_rules AS (
        SELECT DISTINCT ON (c.txn_id)
            c.txn_id,
            c.parsed_id,
            c.merchant_name_norm,
            c.description,
            mr.rule_id,
            mr.category_code,
            mr.subcategory_code,
            mr.confidence,
            'regex'::TEXT AS match_kind
        FROM candidates c
        JOIN spendsense.merchant_rules mr ON (
            mr.active = TRUE
            AND mr.pattern_regex IS NOT NULL
            AND (
                (mr.applies_to = 'merchant' AND LOWER(TRIM(COALESCE(c.merchant_name_norm, ''))) ~* mr.pattern_regex)
                OR (mr.applies_to = 'description' AND LOWER(TRIM(COALESCE(c.description, ''))) ~* mr.pattern_regex)
            )
        )
        ORDER BY c.txn_id, mr.priority DESC, mr.confidence DESC
    ),
    exact_rules AS (
        SELECT DISTINCT ON (c.txn_id)
            c.txn_id,
            c.parsed_id,
            c.merchant_name_norm,
            c.description,
            mr.rule_id,
            mr.category_code,
            mr.subcategory_code,
            mr.confidence,
            'exact'::TEXT AS match_kind
        FROM candidates c
        JOIN spendsense.merchant_rules mr ON mr.merchant_name_norm = c.merchant_for_matching
        WHERE mr.active = TRUE
          AND NOT EXISTS (SELECT 1 FROM regex_rules er WHERE er.txn_id = c.txn_id)
        ORDER BY c.txn_id, mr.priority DESC, mr.confidence DESC
    ),
    exact_dims AS (
        SELECT DISTINCT ON (c.txn_id)
            c.txn_id,
            c.parsed_id,
            c.merchant_name_norm,
            c.description,
            NULL::UUID AS rule_id,
            dm.category_code,
            dm.subcategory_code,
            0.95::NUMERIC AS confidence,
            'exact_dim'::TEXT AS match_kind
        FROM candidates c
        JOIN spendsense.dim_merchant dm ON (
            dm.normalized_name = c.merchant_for_matching
            OR c.merchant_for_matching LIKE '%' || dm.normalized_name || '%'
            OR dm.normalized_name LIKE '%' || c.merchant_for_matching || '%'
            OR similarity(dm.normalized_name, c.merchant_for_matching) >= 0.70
        )
        WHERE dm.active = TRUE
          AND NOT EXISTS (SELECT 1 FROM regex_rules er WHERE er.txn_id = c.txn_id)
          AND NOT EXISTS (SELECT 1 FROM exact_rules er WHERE er.txn_id = c.txn_id)
        ORDER BY c.txn_id, 
            CASE 
                WHEN dm.normalized_name = c.merchant_for_matching THEN 1
                WHEN similarity(dm.normalized_name, c.merchant_for_matching) >= 0.80 THEN 2
                ELSE 3
            END
    ),
    exact_matches AS (
        SELECT * FROM regex_rules
        UNION ALL
        SELECT * FROM exact_rules
        UNION ALL
        SELECT * FROM exact_dims
    ),
    fuzzy_matches AS (
        SELECT DISTINCT ON (c.txn_id)
            c.txn_id,
            c.parsed_id,
            c.merchant_name_norm,
            c.description,
            mr.rule_id,
            mr.category_code,
            mr.subcategory_code,
            GREATEST(0.80, COALESCE(mr.confidence, 0.80)) AS confidence,
            'fuzzy'::TEXT AS match_kind
        FROM candidates c
        JOIN spendsense.merchant_rules mr ON (
            mr.active = TRUE
            AND similarity(mr.merchant_name_norm, c.merchant_for_matching) >= 0.40
        )
        WHERE NOT EXISTS (SELECT 1 FROM exact_matches em WHERE em.txn_id = c.txn_id)
        ORDER BY c.txn_id, similarity(mr.merchant_name_norm, c.merchant_for_matching) DESC, mr.priority DESC
    ),
    keyword_matches AS (
        SELECT DISTINCT ON (c.txn_id)
            c.txn_id,
            c.parsed_id,
            c.merchant_name_norm,
            c.description,
            mr.rule_id,
            mr.category_code,
            mr.subcategory_code,
            LEAST(1.0, COALESCE(mr.confidence, 0.70)) AS confidence,
            'keyword'::TEXT AS match_kind
        FROM candidates c
        JOIN spendsense.merchant_rules mr ON (
            mr.active = TRUE
            AND mr.brand_keywords IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM unnest(mr.brand_keywords) bk
                WHERE c.merchant_for_matching ILIKE '%' || lower(bk) || '%'
                   OR LOWER(TRIM(COALESCE(c.description, ''))) ILIKE '%' || lower(bk) || '%'
            )
        )
        WHERE NOT EXISTS (SELECT 1 FROM exact_matches em WHERE em.txn_id = c.txn_id)
          AND NOT EXISTS (SELECT 1 FROM fuzzy_matches fm WHERE fm.txn_id = c.txn_id)
        ORDER BY c.txn_id, mr.priority DESC, mr.confidence DESC
    ),
    all_matches AS (
        SELECT * FROM exact_matches
        UNION ALL
        SELECT * FROM fuzzy_matches
        UNION ALL
        SELECT * FROM keyword_matches
    )
    SELECT
        c.txn_id,
        c.parsed_id,
        c.merchant_name_norm,
        c.description,
        c.parsed_direction,
        c.direction,
        c.channel_type,
        c.counterparty_name,
        CASE 
            WHEN am.txn_id IS NOT NULL THEN
                jsonb_build_object(
                    'rule_id', am.rule_id,
                    'merchant_name_norm', COALESCE(am.merchant_name_norm, c.merchant_name_norm),
                    'category_code', am.category_code,
                    'subcategory_code', am.subcategory_code,
                    'confidence', am.confidence,
                    'match_kind', am.match_kind
                )
            ELSE NULL
        END AS match_result
    FROM candidates c
    LEFT JOIN all_matches am ON am.txn_id = c.txn_id
),
resolved AS (
    SELECT
        c.parsed_id,
        c.txn_id,
        c.bank_code,
        c.txn_date,
        c.amount,
        c.cr_dr,
        c.parsed_direction AS direction,
        c.channel_type,
        COALESCE(
            mm.match_result->>'category_code',
            'shopping'
        ) AS category_code,
        COALESCE(
            mm.match_result->>'subcategory_code',
            CASE 
                WHEN mm.match_result->>'category_code' = 'loan_payments'
                    THEN 'credit_card_payment'
                WHEN mm.match_result->>'category_code' = 'shopping'
                    THEN 'amazon'
                ELSE 'amazon'
            END
        ) AS subcategory_code,
        CASE
            WHEN c.parsed_direction = 'IN' OR c.direction = 'credit' 
                THEN 'income'
            ELSE (
                SELECT dc.txn_type 
                FROM spendsense.dim_category dc 
                WHERE dc.category_code = COALESCE(
                    mm.match_result->>'category_code',
                    'shopping'
                )
            )
        END AS txn_type,
        NULL::INTEGER AS matched_rule_id,
        COALESCE(
            (mm.match_result->>'confidence')::NUMERIC(3,2),
            0.90
        ) AS confidence,
        CASE WHEN mm.match_result IS NOT NULL THEN TRUE ELSE FALSE END AS is_matched
    FROM candidates c
    LEFT JOIN merchant_matches mm ON mm.txn_id = c.txn_id
)
SELECT
    r.parsed_id,
    r.bank_code,
    r.txn_date,
    r.amount,
    r.cr_dr,
    r.channel_type,
    r.direction,
    r.category_code AS category_id,
    r.subcategory_code AS subcategory_id,
    r.txn_type AS cat_l1,
    r.matched_rule_id AS rule_id,
    r.confidence,
    NOW()
FROM resolved r
WHERE r.parsed_id IS NOT NULL
    AND r.is_matched = TRUE
ON CONFLICT (parsed_id) DO NOTHING;

-- Now handle unmatched transactions as transfers (personal names) or shopping
-- This is a simplified version - the full Python logic would be better
INSERT INTO spendsense.txn_enriched (
    parsed_id, bank_code, txn_date, amount, cr_dr, channel_type, direction,
    category_id, subcategory_id, cat_l1, rule_id, confidence, created_at
)
SELECT
    tp.parsed_id,
    tp.bank_code,
    tp.txn_date,
    tp.amount,
    tp.cr_dr,
    tp.channel_type,
    tp.direction,
    CASE 
        WHEN tp.direction = 'OUT' THEN 'transfers_out'
        ELSE 'transfers_in'
    END AS category_id,
    CASE 
        WHEN tp.direction = 'OUT' AND tp.channel_type = 'UPI' THEN 'tr_out_wallet'
        WHEN tp.direction = 'OUT' THEN 'tr_out_other'
        ELSE 'tr_in_other'
    END AS subcategory_id,
    'transfer' AS cat_l1,
    NULL AS rule_id,
    0.70 AS confidence,
    NOW()
FROM spendsense.txn_parsed tp
JOIN spendsense.txn_fact tf ON tp.fact_txn_id = tf.txn_id
WHERE NOT EXISTS (
    SELECT 1 FROM spendsense.txn_enriched te
    WHERE te.parsed_id = tp.parsed_id
)
ON CONFLICT (parsed_id) DO NOTHING;

COMMIT;

