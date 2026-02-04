import asyncpg  # type: ignore[import-untyped]
import logging
from typing import Iterable

from ..models import StagingRecord
from ..services.category_inference import _infer_category_from_keywords, _looks_like_personal_name
from ..services.ml_category_model import ml_predict_category
from ..services.merchant_lookup import lookup_merchant_category

logger = logging.getLogger(__name__)


def normalize_staging_to_fact(records: Iterable[StagingRecord]) -> None:
    """Placeholder for normalization ETL.

    According to `02_spendsense.md`, this job hashes transactions, normalizes merchants,
    and writes canonical facts. Implementation will be added once data stores are wired.
    """

    # TODO: implement transformation + write to txn_fact
    for record in records:
        _ = record  # pragma: no cover - placeholder


async def enrich_transactions(
    conn: asyncpg.Connection,
    user_id: str,
    upload_id: str | None = None,
) -> int:
    """Enrich transactions with categories and subcategories using merchant rules.
    
    Args:
        conn: Database connection
        user_id: User ID to enrich transactions for
        upload_id: Optional upload batch ID to limit enrichment to specific batch
        
    Returns:
        Number of transactions enriched
    """
    # Build query with proper parameterization
    if upload_id:
        # Debug: Check how many parsed transactions exist for this batch before enrichment
        debug_count = await conn.fetchval("""
            SELECT COUNT(DISTINCT tp.parsed_id)
            FROM spendsense.txn_fact tf
            JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
            WHERE tf.upload_id = $1
                AND NOT EXISTS (
                    SELECT 1 FROM spendsense.txn_enriched te
                    WHERE te.parsed_id = tp.parsed_id
                )
        """, upload_id)
        logger.info(f"[ENRICHMENT] Found {debug_count} unenriched parsed transactions for batch {upload_id}")
        
        # When upload_id is provided, find parsed transactions from this batch
        # Use upload_id directly from txn_fact (same as parsing logic)
        query = """
    WITH candidates AS (
        -- Find parsed transactions from this batch that need enrichment
        SELECT 
            f.txn_id,
            f.user_id,
            f.upload_id,
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
            -- Use counterparty_name as fallback when merchant_name_norm is generic or missing
            COALESCE(
                NULLIF(LOWER(TRIM(f.merchant_name_norm)), ''),
                NULLIF(LOWER(TRIM(tp.counterparty_name)), ''),
                LOWER(TRIM(f.description))
            ) AS merchant_for_matching
        FROM spendsense.txn_fact f
        JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
        WHERE f.upload_id = $2
            AND f.user_id = $1
            AND NOT EXISTS (
                SELECT 1 FROM spendsense.txn_enriched e
                WHERE e.parsed_id = tp.parsed_id
            )
    ),
    merchant_matches AS (
        -- Batch matching: join all candidates with merchant_rules and dim_merchant at once
        -- This is much faster than calling fn_match_merchant() for each row
        WITH regex_rules AS (
            -- First check regex patterns (highest priority for pattern-based rules)
            -- Use ~* for case-insensitive regex matching in PostgreSQL
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
                    (mr.applies_to = 'merchant' AND c.merchant_for_matching ~* mr.pattern_regex)
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
            JOIN spendsense.merchant_rules mr ON LOWER(TRIM(COALESCE(mr.merchant_name_norm, ''))) = c.merchant_for_matching
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
                LOWER(TRIM(COALESCE(dm.normalized_name, ''))) = c.merchant_for_matching
                OR c.merchant_for_matching LIKE '%' || LOWER(TRIM(COALESCE(dm.normalized_name, ''))) || '%'
                OR LOWER(TRIM(COALESCE(dm.normalized_name, ''))) LIKE '%' || c.merchant_for_matching || '%'
                OR similarity(LOWER(TRIM(COALESCE(dm.normalized_name, ''))), c.merchant_for_matching) >= 0.70
            )
            WHERE dm.active = TRUE
              AND NOT EXISTS (SELECT 1 FROM regex_rules er WHERE er.txn_id = c.txn_id)
              AND NOT EXISTS (SELECT 1 FROM exact_rules er WHERE er.txn_id = c.txn_id)
            ORDER BY c.txn_id, 
                CASE 
                    WHEN LOWER(TRIM(COALESCE(dm.normalized_name, ''))) = c.merchant_for_matching THEN 1
                    WHEN similarity(LOWER(TRIM(COALESCE(dm.normalized_name, ''))), c.merchant_for_matching) >= 0.80 THEN 2
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
                AND similarity(LOWER(TRIM(COALESCE(mr.merchant_name_norm, ''))), c.merchant_for_matching) >= 0.40
            )
            WHERE NOT EXISTS (SELECT 1 FROM exact_matches em WHERE em.txn_id = c.txn_id)
            ORDER BY c.txn_id, similarity(LOWER(TRIM(COALESCE(mr.merchant_name_norm, ''))), c.merchant_for_matching) DESC, mr.priority DESC
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
            c.bank_code AS bank_code,  -- From tp (parsed)
            c.txn_date,
            c.amount,
            c.cr_dr,
            c.parsed_direction AS direction,  -- Use parsed direction (IN/OUT) instead of fact direction (credit/debit)
            c.channel_type,
            -- Extract category_code from match_result JSONB
            COALESCE(
                mm.match_result->>'category_code',
                'shopping'
            ) AS category_code,
            -- Extract subcategory_code from match_result JSONB
            COALESCE(
                mm.match_result->>'subcategory_code',
                CASE 
                    WHEN mm.match_result->>'category_code' = 'loan_payments'
                        THEN 'credit_card_payment'  -- Default for loan_payments
                    WHEN mm.match_result->>'category_code' = 'shopping'
                        THEN 'amazon'  -- Default for shopping
                    ELSE 'amazon'  -- Default fallback
                END
            ) AS subcategory_code,
            -- Determine txn_type
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
            -- Extract rule_id (UUID from merchant_rules, but we store as NULL since txn_enriched.rule_id is INT)
            NULL::INTEGER AS matched_rule_id,
            -- Extract confidence from match_result
            COALESCE(
                (mm.match_result->>'confidence')::NUMERIC(3,2),
                0.90
            ) AS confidence,
            -- Flag to indicate if this was matched
            CASE WHEN mm.match_result IS NOT NULL THEN TRUE ELSE FALSE END AS is_matched
        FROM candidates c
        LEFT JOIN merchant_matches mm ON mm.txn_id = c.txn_id
    )
    INSERT INTO spendsense.txn_enriched (
        parsed_id, bank_code, txn_date, amount, cr_dr, channel_type, direction,
        category_id, subcategory_id, cat_l1, rule_id, confidence, created_at
    )
    SELECT
        r.parsed_id,
        r.bank_code,
        r.txn_date,
        r.amount,
        r.cr_dr,
        r.channel_type,
        r.direction,  -- Already using parsed_direction (IN/OUT) from candidates
        r.category_code AS category_id,
        r.subcategory_code AS subcategory_id,
        r.txn_type AS cat_l1,
        r.matched_rule_id AS rule_id,
        r.confidence,  -- Use dynamic confidence from fn_match_merchant()
        NOW()
    FROM resolved r
    WHERE r.parsed_id IS NOT NULL
        AND r.is_matched = TRUE  -- Only insert matched transactions (unmatched handled in Python)
        AND r.category_code IS NOT NULL  -- Ensure category_code is never NULL
        AND r.subcategory_code IS NOT NULL  -- Ensure subcategory_code is never NULL
    ON CONFLICT (parsed_id) DO NOTHING
    RETURNING parsed_id
    """
        params = (user_id, upload_id)
    else:
        query = """
    WITH candidates AS (
        SELECT 
            f.txn_id,
            f.user_id,
            f.upload_id,
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
            -- Use counterparty_name as fallback when merchant_name_norm is generic or missing
            COALESCE(
                NULLIF(LOWER(TRIM(f.merchant_name_norm)), ''),
                NULLIF(LOWER(TRIM(tp.counterparty_name)), ''),
                LOWER(TRIM(f.description))
            ) AS merchant_for_matching
        FROM spendsense.txn_fact f
        JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
        WHERE f.user_id = $1
            AND NOT EXISTS (
                SELECT 1 FROM spendsense.txn_enriched e
                WHERE e.parsed_id = tp.parsed_id
            )
    ),
    merchant_matches AS (
        -- Batch matching: join all candidates with merchant_rules and dim_merchant at once
        -- This is much faster than calling fn_match_merchant() for each row
        WITH regex_rules AS (
            -- First check regex patterns (highest priority for pattern-based rules)
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
                    (mr.applies_to = 'merchant' AND c.merchant_for_matching ~ mr.pattern_regex)
                    OR (mr.applies_to = 'description' AND LOWER(TRIM(COALESCE(c.description, ''))) ~ mr.pattern_regex)
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
            JOIN spendsense.merchant_rules mr ON LOWER(TRIM(COALESCE(mr.merchant_name_norm, ''))) = c.merchant_for_matching
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
                LOWER(TRIM(COALESCE(dm.normalized_name, ''))) = c.merchant_for_matching
                OR c.merchant_for_matching LIKE '%' || LOWER(TRIM(COALESCE(dm.normalized_name, ''))) || '%'
                OR LOWER(TRIM(COALESCE(dm.normalized_name, ''))) LIKE '%' || c.merchant_for_matching || '%'
                OR similarity(LOWER(TRIM(COALESCE(dm.normalized_name, ''))), c.merchant_for_matching) >= 0.70
            )
            WHERE dm.active = TRUE
              AND NOT EXISTS (SELECT 1 FROM regex_rules er WHERE er.txn_id = c.txn_id)
              AND NOT EXISTS (SELECT 1 FROM exact_rules er WHERE er.txn_id = c.txn_id)
            ORDER BY c.txn_id, 
                CASE 
                    WHEN LOWER(TRIM(COALESCE(dm.normalized_name, ''))) = c.merchant_for_matching THEN 1
                    WHEN similarity(LOWER(TRIM(COALESCE(dm.normalized_name, ''))), c.merchant_for_matching) >= 0.80 THEN 2
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
                AND similarity(LOWER(TRIM(COALESCE(mr.merchant_name_norm, ''))), c.merchant_for_matching) >= 0.40
            )
            WHERE NOT EXISTS (SELECT 1 FROM exact_matches em WHERE em.txn_id = c.txn_id)
            ORDER BY c.txn_id, similarity(LOWER(TRIM(COALESCE(mr.merchant_name_norm, ''))), c.merchant_for_matching) DESC, mr.priority DESC
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
            c.bank_code AS bank_code,  -- From tp (parsed)
            c.txn_date,
            c.amount,
            c.cr_dr,
            c.parsed_direction AS direction,  -- Use parsed direction (IN/OUT) instead of fact direction (credit/debit)
            c.channel_type,
            -- Extract category_code from match_result JSONB
            COALESCE(
                mm.match_result->>'category_code',
                'shopping'
            ) AS category_code,
            -- Extract subcategory_code from match_result JSONB
            COALESCE(
                mm.match_result->>'subcategory_code',
                CASE 
                    WHEN mm.match_result->>'category_code' = 'loan_payments'
                        THEN 'credit_card_payment'  -- Default for loan_payments
                    WHEN mm.match_result->>'category_code' = 'shopping'
                        THEN 'amazon'  -- Default for shopping
                    ELSE 'amazon'  -- Default fallback
                END
            ) AS subcategory_code,
            -- Determine txn_type
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
            -- Extract rule_id (UUID from merchant_rules, but we store as NULL since txn_enriched.rule_id is INT)
            NULL::INTEGER AS matched_rule_id,
            -- Extract confidence from match_result
            COALESCE(
                (mm.match_result->>'confidence')::NUMERIC(3,2),
                0.90
            ) AS confidence,
            -- Flag to indicate if this was matched
            CASE WHEN mm.match_result IS NOT NULL THEN TRUE ELSE FALSE END AS is_matched
        FROM candidates c
        LEFT JOIN merchant_matches mm ON mm.txn_id = c.txn_id
    )
    INSERT INTO spendsense.txn_enriched (
        parsed_id, bank_code, txn_date, amount, cr_dr, channel_type, direction,
        category_id, subcategory_id, cat_l1, rule_id, confidence, created_at
    )
    SELECT
        r.parsed_id,
        r.bank_code,
        r.txn_date,
        r.amount,
        r.cr_dr,
        r.channel_type,
        r.direction,  -- Already using parsed_direction (IN/OUT) from candidates
        r.category_code AS category_id,
        r.subcategory_code AS subcategory_id,
        r.txn_type AS cat_l1,
        r.matched_rule_id AS rule_id,
        r.confidence,  -- Use dynamic confidence from fn_match_merchant()
        NOW()
    FROM resolved r
    WHERE r.parsed_id IS NOT NULL
        AND r.is_matched = TRUE  -- Only insert matched transactions (unmatched handled in Python)
        AND r.category_code IS NOT NULL  -- Ensure category_code is never NULL
        AND r.subcategory_code IS NOT NULL  -- Ensure subcategory_code is never NULL
    ON CONFLICT (parsed_id) DO NOTHING
    RETURNING parsed_id
    """
        params = (user_id,)
    
    try:
        # First, run a SELECT query to get match results BEFORE inserting
        # This allows us to check for personal names and override before insert
        # Extract the CTEs and create a SELECT query instead of INSERT
        if "INSERT INTO spendsense.txn_enriched" in query:
            # Get everything up to the INSERT statement (all the CTEs)
            cte_part = query.split("INSERT INTO spendsense.txn_enriched")[0]
            # Create a SELECT query that returns match results
            select_query = cte_part + """
        SELECT
            mm.parsed_id,
            mm.merchant_name_norm,
            mm.counterparty_name,
            mm.description,
            mm.channel_type,
            mm.parsed_direction,
            mm.direction,
            mm.match_result
        FROM merchant_matches mm
        WHERE mm.parsed_id IS NOT NULL
        """
        else:
            # Fallback: use the original query structure
            select_query = query
        
        # Run SELECT to get match results
        match_results = await conn.fetch(select_query, *params)
        
        # CRITICAL: Check personal names for ALL matched transactions and override if needed
        # Personal names should ALWAYS be transfers, even if SQL matched them to merchant_rules
        personal_name_overrides = {}
        
        for row in match_results:
            parsed_id = row.get('parsed_id')
            if not parsed_id:
                continue
            
            merchant_norm = row.get('merchant_name_norm') or ''
            counterparty = row.get('counterparty_name') or ''
            description = row.get('description') or ''
            channel = row.get('channel_type') or ''
            parsed_dir = row.get('parsed_direction') or ''
            fact_dir = row.get('direction') or ''
            
            merchant_for_check = merchant_norm or counterparty or description
            merchant_normalized = merchant_for_check.lower().strip() if merchant_for_check else ''
            
            # Extract category from match_result if it exists
            match_result = row.get('match_result')
            current_category = None
            if match_result:
                # match_result is JSONB from asyncpg (returns as dict)
                if isinstance(match_result, dict):
                    current_category = match_result.get('category_code')
            
            # CRITICAL: Only check for personal names if:
            # 1. No merchant rule matched (current_category is None or transfers)
            # 2. Merchant is NOT in dim_merchant (known merchants should not be treated as personal names)
            # Check both exact match and partial match (e.g., "cred club" contains "cred")
            is_known_merchant = False
            if merchant_normalized:
                known_merchant_check = await conn.fetchval("""
                    SELECT COUNT(*) > 0
                    FROM spendsense.dim_merchant dm
                    LEFT JOIN spendsense.merchant_alias ma ON ma.merchant_id = dm.merchant_id
                    WHERE dm.active = TRUE
                      AND (
                          dm.normalized_name = $1
                          OR ma.normalized_alias = $1
                          OR $1 LIKE '%' || dm.normalized_name || '%'
                          OR $1 LIKE '%' || ma.normalized_alias || '%'
                      )
                """, merchant_normalized)
                is_known_merchant = known_merchant_check or False
            
            # Check if it's a personal name (only if not a known merchant and no strong match)
            if merchant_normalized and not is_known_merchant and _looks_like_personal_name(merchant_normalized):
                # If it's categorized as something other than transfers, override it
                if current_category not in ['transfers_out', 'transfers_in']:
                    direction = 'debit' if parsed_dir == 'OUT' or fact_dir == 'debit' else 'credit'
                    new_category = "transfers_out" if direction == "debit" else "transfers_in"
                    new_subcategory = "tr_out_wallet" if channel == "UPI" else "tr_out_other" if direction == "debit" else "tr_in_other"
                    
                    personal_name_overrides[parsed_id] = {
                        'category_code': new_category,
                        'subcategory_code': new_subcategory,
                        'merchant': merchant_normalized[:50],
                        'old_category': current_category,
                    }
                    logger.info(
                        f"[PERSONAL NAME OVERRIDE] {parsed_id}: {merchant_normalized[:40]} → "
                        f"{current_category} → {new_category}/{new_subcategory}"
                    )
        
        # Now run the actual INSERT query
        inserted_result = await conn.fetch(query, *params)
        matched_count = len(inserted_result)
        
        # Apply personal name overrides AFTER insert
        if personal_name_overrides:
            for parsed_id, override in personal_name_overrides.items():
                # Get txn_type for the new category
                txn_type_row = await conn.fetchrow(
                    "SELECT txn_type FROM spendsense.dim_category WHERE category_code = $1",
                    override['category_code']
                )
                txn_type = txn_type_row['txn_type'] if txn_type_row else 'transfer'
                
                # Update txn_enriched
                await conn.execute(
                    """
                    UPDATE spendsense.txn_enriched
                    SET category_id = $1,
                        subcategory_id = $2,
                        cat_l1 = $3,
                        confidence = 0.95
                    WHERE parsed_id = $4
                    """,
                    override['category_code'],
                    override['subcategory_code'],
                    txn_type,
                    parsed_id,
                )
            logger.info(f"Applied {len(personal_name_overrides)} personal name overrides")
        
        # For unmatched transactions, use Python-based inference (ML + heuristic)
        # Fetch unmatched transactions
        if upload_id:
            unmatched_query = """
                SELECT 
                    tp.parsed_id,
                    f.txn_id,
                    f.description,
                    f.merchant_name_norm,
                    tp.counterparty_name,
                    tp.channel_type,
                    tp.direction AS parsed_direction,
                    f.direction AS fact_direction,
                    f.amount
                FROM spendsense.txn_fact f
                JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
                WHERE f.upload_id = $2
                    AND f.user_id = $1
                    AND NOT EXISTS (
                        SELECT 1 FROM spendsense.txn_enriched e
                        WHERE e.parsed_id = tp.parsed_id
                    )
            """
            unmatched_params = (user_id, upload_id)
        else:
            unmatched_query = """
                SELECT 
                    tp.parsed_id,
                    f.txn_id,
                    f.description,
                    f.merchant_name_norm,
                    tp.counterparty_name,
                    tp.channel_type,
                    tp.direction AS parsed_direction,
                    f.direction AS fact_direction,
                    f.amount
                FROM spendsense.txn_fact f
                JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
                WHERE f.user_id = $1
                    AND NOT EXISTS (
                        SELECT 1 FROM spendsense.txn_enriched e
                        WHERE e.parsed_id = tp.parsed_id
                    )
            """
            unmatched_params = (user_id,)
        
        unmatched_rows = await conn.fetch(unmatched_query, *unmatched_params)
        inferred_count = 0
        
        # Pre-fetch default subcategories for all categories (to avoid per-transaction queries)
        default_subcategories = {}
        default_subcat_rows = await conn.fetch("""
            SELECT DISTINCT ON (category_code) category_code, subcategory_code
            FROM spendsense.dim_subcategory
            WHERE active = TRUE
            ORDER BY category_code, display_order ASC
        """)
        for row in default_subcat_rows:
            default_subcategories[row['category_code']] = row['subcategory_code']
        
        # Process unmatched transactions with Python inference
        for row in unmatched_rows:
            parsed_id = row['parsed_id']
            description = row['description'] or ''
            merchant_norm = row['merchant_name_norm'] or ''
            counterparty = row['counterparty_name'] or ''
            channel = row['channel_type'] or ''
            parsed_dir = row['parsed_direction'] or ''
            fact_dir = row['fact_direction'] or ''
            amount = float(row['amount'] or 0)
            
            # Use counterparty as fallback for merchant
            merchant_for_inference = merchant_norm or counterparty or description
            
            # Normalize merchant for lookup
            merchant_normalized = merchant_for_inference.lower().strip() if merchant_for_inference else ''
            
            # Determine direction for inference
            direction = 'debit' if parsed_dir == 'OUT' or fact_dir == 'debit' else 'credit'
            
            # Step 0: Check if it's a personal name FIRST (highest priority)
            # Personal names should ALWAYS be transfers, even if found in merchant master
            category_code = None
            subcategory_code = None
            confidence = 0.5
            inference_method = 'heuristic'
            
            is_personal_name = False
            if merchant_normalized:
                is_personal_name = _looks_like_personal_name(merchant_normalized)
                if is_personal_name:
                    # Personal name = always transfers (highest priority)
                    category_code = "transfers_out" if direction == "debit" else "transfers_in"
                    subcategory_code = "tr_out_wallet" if channel == "UPI" else "tr_out_other" if direction == "debit" else "tr_in_other"
                    confidence = 0.95  # High confidence for personal names
                    inference_method = 'personal_name'
                    logger.info(
                        f"[ENRICH INFERENCE] {parsed_id} | Personal Name: {category_code}/{subcategory_code} | "
                        f"merchant={merchant_normalized[:50]}"
                    )
            
            # Step 1: If not a personal name, try merchant master (dim_merchant + merchant_alias)
            # If we know the brand, trust the brand. Everything else becomes P2P transfer by default.
            if not category_code and merchant_normalized:
                cat_from_master, sub_from_master = await lookup_merchant_category(conn, merchant_normalized)
                if cat_from_master:
                    category_code = cat_from_master
                    subcategory_code = sub_from_master
                    confidence = 0.95  # High confidence for known merchants
                    inference_method = 'merchant_master'
                    logger.info(
                        f"[ENRICH INFERENCE] {parsed_id} | Merchant Master: {category_code}/{subcategory_code} | "
                        f"merchant={merchant_normalized[:50]}"
                    )
            
            # Step 2: If merchant master didn't match, try ML prediction
            if not category_code:
            
                ml_result = ml_predict_category(
                    description=description,
                    merchant=merchant_for_inference,
                    amount=amount,
                )
                
                if ml_result and ml_result.get("confidence", 0) >= 0.55:
                    category_code = ml_result.get("category_code")
                    confidence = ml_result.get("confidence", 0.55)
                    inference_method = 'ml'
                    logger.info(
                        f"[ENRICH INFERENCE] {parsed_id} | ML: {category_code} "
                        f"(conf={confidence:.2f}) | merchant={merchant_for_inference[:50]}"
                    )
                else:
                    # Fallback to heuristic (keyword-based inference)
                    # This handles UPI P2P vs merchant logic
                    category_code = _infer_category_from_keywords(
                        merchant_for_inference.lower() + " " + description.lower(),
                        direction
                    )
                    confidence = 0.6  # Lower confidence for heuristic
                    inference_method = 'heuristic'
                    logger.info(
                        f"[ENRICH INFERENCE] {parsed_id} | Heuristic: {category_code} | "
                        f"merchant={merchant_for_inference[:50]} | desc={description[:50]}"
                    )
            
            # Determine subcategory based on category
            if category_code == 'transfers_out':
                subcategory_code = 'tr_out_wallet' if channel == 'UPI' else 'tr_out_other'
            elif category_code == 'transfers_in':
                subcategory_code = 'tr_in_other'  # Default for incoming transfers
            elif category_code == 'shopping':
                subcategory_code = 'shop_marketplaces'  # Use shop_marketplaces instead of shop_online
            elif category_code == 'banks':
                subcategory_code = 'bank_interest'  # Use 'banks' category code
            elif category_code == 'groceries':
                # Check if it's meat-related
                search_text_lower = (merchant_for_inference + " " + description).lower()
                if any(k in search_text_lower for k in ['chicken', 'meat', 'poultry', 'seafood', 'fresh chicken']):
                    subcategory_code = 'groc_meat'
                elif any(k in search_text_lower for k in ['bigbasket', 'blinkit', 'zepto', 'grofers', 'dunzo', 'online']):
                    subcategory_code = 'groc_online'  # Online groceries
                elif any(k in search_text_lower for k in ['vegetable', 'fruit', 'fv', 'veggie']):
                    subcategory_code = 'groc_fv'  # Vegetable & Fruit Stores
                else:
                    subcategory_code = 'groc_hyper'  # Default to hypermarkets for general groceries
            elif category_code == 'transport':
                # Check if it's public transport
                search_text_lower = (merchant_for_inference + " " + description).lower()
                if any(k in search_text_lower for k in ['srtc', 'rtc', 'apsrtc', 'bus', 'railway', 'irctc']):
                    subcategory_code = 'tr_public'
                elif any(k in search_text_lower for k in ['petrol', 'diesel', 'fuel']):
                    subcategory_code = 'tr_fuel'
                else:
                    subcategory_code = 'tr_other'
            elif category_code == 'pets':
                # Check if it's veterinary-related
                search_text_lower = (merchant_for_inference + " " + description).lower()
                if any(k in search_text_lower for k in ['vet', 'veterinary', 'animal clinic', 'vaccine']):
                    subcategory_code = 'pet_vaccine'
                else:
                    subcategory_code = 'pet_food'  # Default pets subcategory
            else:
                # Fallback: use cached default subcategory for this category, or None if not found
                subcategory_code = default_subcategories.get(category_code)
            
            # Ensure category_code is never None (shouldn't happen, but safety check)
            if not category_code:
                logger.warning(f"[ENRICH WARNING] category_code is None for parsed_id {parsed_id}, using 'shopping' as fallback")
                category_code = 'shopping'
                subcategory_code = subcategory_code or 'shop_marketplaces'
                confidence = 0.5  # Low confidence for fallback
            
            # Ensure subcategory_code is set if category_code exists
            if category_code and not subcategory_code:
                # Try to get default subcategory from cache
                subcategory_code = default_subcategories.get(category_code)
                if not subcategory_code:
                    logger.warning(f"[ENRICH WARNING] No subcategory found for category {category_code}, parsed_id {parsed_id}")
                    # Use a generic fallback based on category
                    if category_code in ['transfers_out', 'transfers_in']:
                        subcategory_code = 'tr_out_other' if category_code == 'transfers_out' else 'tr_in_other'
                    else:
                        subcategory_code = 'shop_marketplaces'  # Generic fallback
            
            # Get txn_type from category
            txn_type_row = await conn.fetchrow(
                "SELECT txn_type FROM spendsense.dim_category WHERE category_code = $1",
                category_code
            )
            txn_type = txn_type_row['txn_type'] if txn_type_row else 'wants'
            
            # Final safety check: ensure we never insert NULL category/subcategory
            if not category_code or not subcategory_code:
                logger.error(
                    f"[ENRICH ERROR] Cannot insert enrichment for parsed_id {parsed_id}: "
                    f"category_code={category_code}, subcategory_code={subcategory_code}. Skipping."
                )
                continue  # Skip this transaction
            
            # Insert inferred enrichment
            try:
                await conn.execute(
                    """
                    INSERT INTO spendsense.txn_enriched (
                        parsed_id, bank_code, txn_date, amount, cr_dr, channel_type, direction,
                        category_id, subcategory_id, cat_l1, rule_id, confidence, created_at
                    )
                    SELECT
                        $1,
                        tp.bank_code,
                        tp.txn_date,
                        tp.amount,
                        tp.cr_dr,
                        tp.channel_type,
                        tp.direction,
                        $2,
                        $3,
                        $4,
                        NULL,
                        $5,
                        NOW()
                    FROM spendsense.txn_parsed tp
                    WHERE tp.parsed_id = $1
                    ON CONFLICT (parsed_id) DO NOTHING
                    """,
                    parsed_id,
                    category_code,
                    subcategory_code,
                    txn_type,
                    confidence,
                )
                inferred_count += 1
                
                # Debug logging for first few
                if inferred_count <= 30:
                    logger.info(
                        f"[ENRICH DEBUG] {row.get('txn_id')} | {merchant_for_inference[:40]} | "
                        f"{(description or '')[:60]} | dir={direction} | "
                        f"cat={category_code} | sub={subcategory_code} | method={inference_method}"
                    )
            except Exception as e:
                logger.error(f"Failed to insert inferred enrichment for parsed_id {parsed_id}: {e}")
        
        total_count = matched_count + inferred_count
        if upload_id and total_count == 0:
            # Additional debug for upload_id case
            logger.warning(f"[ENRICHMENT DEBUG] Enrichment returned 0 for batch {upload_id}")
            # Check if there are any parsed transactions at all
            parsed_check = await conn.fetchval("""
                SELECT COUNT(*)
                FROM spendsense.txn_fact tf
                JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
                WHERE tf.upload_id = $1
            """, upload_id)
            logger.info(f"[ENRICHMENT DEBUG] Total parsed transactions for batch {upload_id}: {parsed_check}")
            
            # Check if they're already enriched
            enriched_check = await conn.fetchval("""
                SELECT COUNT(*)
                FROM spendsense.txn_fact tf
                JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
                JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
                WHERE tf.upload_id = $1
            """, upload_id)
            logger.info(f"[ENRICHMENT DEBUG] Already enriched transactions for batch {upload_id}: {enriched_check}")
        logger.info(f"[ENRICHMENT] Matched: {matched_count}, Inferred: {inferred_count}, Total: {total_count}")
        return total_count
    except Exception as e:
        logger.error(f"[ENRICHMENT ERROR] Error during enrichment query: {e}", exc_info=True)
        raise

