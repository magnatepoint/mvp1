#!/usr/bin/env python3
"""
Direct re-enrichment script - uses the actual enrich_transactions function
"""

import asyncio
import asyncpg
import os
import sys
from dotenv import load_dotenv
from pathlib import Path

# Add backend to path
backend_dir = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(backend_dir))

# Load environment variables
env_file = backend_dir / ".env"
if env_file.exists():
    load_dotenv(env_file)

POSTGRES_URL = os.getenv("POSTGRES_URL")
if not POSTGRES_URL:
    print("Error: POSTGRES_URL not found")
    exit(1)

# Import the actual enrichment function
try:
    from app.spendsense.etl.pipeline import enrich_transactions
except ImportError as e:
    print(f"Error importing enrichment function: {e}")
    print("Please ensure all dependencies are installed")
    exit(1)

# Old SQL-only query (kept for reference, but we'll use the actual function)
ENRICHMENT_QUERY_OLD = """
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
            JOIN spendsense.merchant_rules mr ON mr.merchant_name_norm = LOWER(TRIM(COALESCE(c.merchant_name_norm, '')))
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
            JOIN spendsense.dim_merchant dm ON dm.normalized_name = LOWER(TRIM(COALESCE(c.merchant_name_norm, '')))
            WHERE dm.active = TRUE
              AND NOT EXISTS (SELECT 1 FROM regex_rules er WHERE er.txn_id = c.txn_id)
              AND NOT EXISTS (SELECT 1 FROM exact_rules er WHERE er.txn_id = c.txn_id)
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
                AND similarity(mr.merchant_name_norm, LOWER(TRIM(COALESCE(c.merchant_name_norm, '')))) >= 0.40
            )
            WHERE NOT EXISTS (SELECT 1 FROM exact_matches em WHERE em.txn_id = c.txn_id)
            ORDER BY c.txn_id, similarity(mr.merchant_name_norm, LOWER(TRIM(COALESCE(c.merchant_name_norm, '')))) DESC, mr.priority DESC
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
                    WHERE LOWER(TRIM(COALESCE(c.merchant_name_norm, ''))) ILIKE '%' || lower(bk) || '%'
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
    ON CONFLICT (parsed_id) DO NOTHING
    RETURNING parsed_id
"""


async def re_enrich_all():
    """Re-enrich all users' transactions."""
    conn = await asyncpg.connect(
        POSTGRES_URL,
        statement_cache_size=0,
        command_timeout=600
    )
    
    try:
        print("=" * 80)
        print("Re-enriching ALL transactions with new pan shop rules")
        print("=" * 80)
        
        # Get all user IDs
        print("\n1. Fetching all user IDs...")
        user_ids = await conn.fetch("SELECT DISTINCT user_id FROM spendsense.txn_fact ORDER BY user_id")
        total_users = len(user_ids)
        print(f"   Found {total_users} users")
        
        if total_users == 0:
            print("   No users found. Exiting.")
            return
        
        # Count existing enriched
        print("\n2. Counting existing enriched transactions...")
        total_existing = await conn.fetchval("SELECT COUNT(*) FROM spendsense.txn_enriched")
        print(f"   Existing: {total_existing}")
        
        # Delete all enriched records
        print("\n3. Deleting all existing enriched records...")
        await conn.execute("DELETE FROM spendsense.txn_enriched")
        print("   ✓ Deleted all enriched records")
        
        # Re-enrich each user
        print("\n4. Re-enriching transactions for each user...")
        print("=" * 80)
        
        total_enriched = 0
        for idx, row in enumerate(user_ids, 1):
            user_id = str(row['user_id'])
            print(f"\n[{idx}/{total_users}] User: {user_id}")
            
            try:
                # Use the actual enrich_transactions function which includes Python fallback
                enriched_count = await enrich_transactions(conn, user_id, upload_id=None)
                total_enriched += enriched_count
                print(f"   ✓ Enriched {enriched_count} transactions")
            except Exception as e:
                print(f"   ✗ Error: {e}")
                import traceback
                traceback.print_exc()
                continue
        
        print("\n" + "=" * 80)
        print("RE-ENRICHMENT COMPLETE!")
        print(f"Total users: {total_users}")
        print(f"Total transactions enriched: {total_enriched}")
        print("=" * 80)
        
        # Show sample pan shop transactions
        print("\n5. Verifying pan shop categorization...")
        pan_transactions = await conn.fetch("""
            SELECT 
                v.txn_date,
                v.merchant_name_norm,
                v.description,
                v.category_code,
                v.subcategory_code,
                v.amount
            FROM spendsense.vw_txn_effective v
            WHERE (LOWER(v.merchant_name_norm) LIKE '%pan%'
               OR LOWER(v.description) LIKE '%pan%')
            ORDER BY v.txn_date DESC
            LIMIT 10
        """)
        
        if pan_transactions:
            print(f"   Found {len(pan_transactions)} pan shop transactions:")
            for txn in pan_transactions:
                merchant = txn['merchant_name_norm'] or 'N/A'
                desc = txn['description'] or 'N/A'
                cat = txn['category_code']
                subcat = txn['subcategory_code']
                print(f"   - {txn['txn_date']} | {merchant[:30]:30} | {cat}/{subcat}")
        else:
            print("   No pan shop transactions found (this is normal if you don't have any)")
        
    finally:
        await conn.close()


if __name__ == "__main__":
    print("Starting re-enrichment process...")
    asyncio.run(re_enrich_all())

