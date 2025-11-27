import asyncpg  # type: ignore[import-untyped]
from typing import Iterable

from ..models import StagingRecord


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
        query = """
    WITH candidates AS (
        SELECT f.*
        FROM spendsense.txn_fact f
        WHERE f.user_id = $1
            AND f.upload_id = $2
            AND NOT EXISTS (SELECT 1 FROM spendsense.txn_enriched e WHERE e.txn_id = f.txn_id)
    ),
    rule_try AS (
        SELECT
            c.txn_id,
            r.rule_id,
            r.category_code,
            r.subcategory_code,
            r.txn_type_override,
            r.priority,
            CASE r.applies_to
                WHEN 'merchant' THEN (COALESCE(c.merchant_name_norm, '') ~* r.pattern_regex)
                WHEN 'description' THEN (COALESCE(c.description, '') ~* r.pattern_regex)
            END AS is_match
        FROM candidates c
        CROSS JOIN spendsense.merchant_rules r
        WHERE r.active = TRUE
    ),
    rule_rank AS (
        SELECT *
        FROM (
            SELECT
                rt.*,
                ROW_NUMBER() OVER (
                    PARTITION BY rt.txn_id 
                    ORDER BY CASE WHEN rt.is_match THEN 0 ELSE 1 END, rt.priority ASC
                ) AS rn
            FROM rule_try rt
        ) z
        WHERE z.rn = 1
    ),
    resolved AS (
        SELECT
            c.txn_id,
            CASE 
                WHEN rr.is_match AND rr.category_code IS NOT NULL
                    THEN rr.category_code
                ELSE 'shopping'
            END AS category_code,
            CASE 
                WHEN rr.is_match AND rr.subcategory_code IS NOT NULL
                    THEN rr.subcategory_code
                WHEN rr.is_match AND rr.category_code = 'loan_payments'
                    THEN 'credit_card_payment'  -- Default for loan_payments
                WHEN rr.is_match AND rr.category_code = 'shopping'
                    THEN 'amazon'  -- Default for shopping (generic online shopping)
                WHEN NOT rr.is_match OR rr.category_code IS NULL
                    THEN 'amazon'  -- Default for shopping when no rule matches
                ELSE NULL
            END AS subcategory_code,
            CASE
                WHEN rr.is_match AND rr.txn_type_override IS NOT NULL 
                    THEN rr.txn_type_override
                WHEN c.direction = 'credit' 
                    THEN 'income'
                ELSE (
                    SELECT dc.txn_type 
                    FROM spendsense.dim_category dc 
                    WHERE dc.category_code = CASE 
                        WHEN rr.is_match AND rr.category_code IS NOT NULL
                            THEN rr.category_code
                        ELSE 'shopping'
                    END
                )
            END AS txn_type,
            CASE WHEN rr.is_match THEN rr.rule_id ELSE NULL END AS matched_rule_id
        FROM candidates c
        LEFT JOIN rule_rank rr ON rr.txn_id = c.txn_id
    )
    INSERT INTO spendsense.txn_enriched (
        txn_id, matched_rule_id, category_code, subcategory_code, txn_type, rule_confidence, enriched_at
    )
    SELECT
        r.txn_id, 
        r.matched_rule_id, 
        r.category_code, 
        r.subcategory_code, 
        r.txn_type, 
        0.90, 
        NOW()
    FROM resolved r
    ON CONFLICT (txn_id) DO NOTHING
    RETURNING txn_id
    """
        params = (user_id, upload_id)
    else:
        query = """
    WITH candidates AS (
        SELECT f.*
        FROM spendsense.txn_fact f
        WHERE f.user_id = $1
            AND NOT EXISTS (SELECT 1 FROM spendsense.txn_enriched e WHERE e.txn_id = f.txn_id)
    ),
    rule_try AS (
        SELECT
            c.txn_id,
            r.rule_id,
            r.category_code,
            r.subcategory_code,
            r.txn_type_override,
            r.priority,
            CASE r.applies_to
                WHEN 'merchant' THEN (COALESCE(c.merchant_name_norm, '') ~* r.pattern_regex)
                WHEN 'description' THEN (COALESCE(c.description, '') ~* r.pattern_regex)
            END AS is_match
        FROM candidates c
        CROSS JOIN spendsense.merchant_rules r
        WHERE r.active = TRUE
    ),
    rule_rank AS (
        SELECT *
        FROM (
            SELECT
                rt.*,
                ROW_NUMBER() OVER (
                    PARTITION BY rt.txn_id 
                    ORDER BY CASE WHEN rt.is_match THEN 0 ELSE 1 END, rt.priority ASC
                ) AS rn
            FROM rule_try rt
        ) z
        WHERE z.rn = 1
    ),
    resolved AS (
        SELECT
            c.txn_id,
            CASE 
                WHEN rr.is_match AND rr.category_code IS NOT NULL
                    THEN rr.category_code
                ELSE 'shopping'
            END AS category_code,
            CASE 
                WHEN rr.is_match AND rr.subcategory_code IS NOT NULL
                    THEN rr.subcategory_code
                WHEN rr.is_match AND rr.category_code = 'loan_payments'
                    THEN 'credit_card_payment'  -- Default for loan_payments
                WHEN rr.is_match AND rr.category_code = 'shopping'
                    THEN 'amazon'  -- Default for shopping (generic online shopping)
                WHEN NOT rr.is_match OR rr.category_code IS NULL
                    THEN 'amazon'  -- Default for shopping when no rule matches
                ELSE NULL
            END AS subcategory_code,
            CASE
                WHEN rr.is_match AND rr.txn_type_override IS NOT NULL 
                    THEN rr.txn_type_override
                WHEN c.direction = 'credit' 
                    THEN 'income'
                ELSE (
                    SELECT dc.txn_type 
                    FROM spendsense.dim_category dc 
                    WHERE dc.category_code = CASE 
                        WHEN rr.is_match AND rr.category_code IS NOT NULL
                            THEN rr.category_code
                        ELSE 'shopping'
                    END
                )
            END AS txn_type,
            CASE WHEN rr.is_match THEN rr.rule_id ELSE NULL END AS matched_rule_id
        FROM candidates c
        LEFT JOIN rule_rank rr ON rr.txn_id = c.txn_id
    )
    INSERT INTO spendsense.txn_enriched (
        txn_id, matched_rule_id, category_code, subcategory_code, txn_type, rule_confidence, enriched_at
    )
    SELECT
        r.txn_id, 
        r.matched_rule_id, 
        r.category_code, 
        r.subcategory_code, 
        r.txn_type, 
        0.90, 
        NOW()
    FROM resolved r
    ON CONFLICT (txn_id) DO NOTHING
    RETURNING txn_id
    """
        params = (user_id,)
    
    result = await conn.fetch(query, *params)
    return len(result)

