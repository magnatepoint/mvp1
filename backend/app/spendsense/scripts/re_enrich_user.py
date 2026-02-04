#!/usr/bin/env python3
"""
Re-enrich transactions for a user
Deletes existing enriched records and re-runs enrichment with updated merchant rules
"""

import asyncio
import asyncpg
import sys
from pathlib import Path

# Add backend to path
backend_path = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(backend_path))

from app.core.config import get_settings
from app.spendsense.etl.pipeline import enrich_transactions


async def re_enrich_user(user_id: str):
    """Delete enriched records and re-enrich for a user."""
    settings = get_settings()
    
    conn = await asyncpg.connect(
        str(settings.postgres_dsn),
        statement_cache_size=0,
        command_timeout=300
    )
    
    try:
        print(f"Re-enriching transactions for user: {user_id}")
        print("-" * 80)
        
        # 1. Count existing enriched records
        existing_count = await conn.fetchval("""
            SELECT COUNT(*) 
            FROM spendsense.txn_enriched e
            WHERE EXISTS (
                SELECT 1 FROM spendsense.txn_parsed tp
                JOIN spendsense.txn_fact tf ON tf.txn_id = tp.fact_txn_id
                WHERE e.parsed_id = tp.parsed_id
                AND tf.user_id = $1
            )
        """, user_id)
        print(f"Existing enriched transactions: {existing_count}")
        
        # 2. Delete existing enriched records
        print("Deleting existing enriched records...")
        deleted = await conn.execute("""
            DELETE FROM spendsense.txn_enriched 
            WHERE parsed_id IN (
                SELECT tp.parsed_id
                FROM spendsense.txn_parsed tp
                JOIN spendsense.txn_fact tf ON tp.fact_txn_id = tf.txn_id
                WHERE tf.user_id = $1
            )
        """, user_id)
        print(f"Deleted: {deleted}")
        
        # 3. Re-run enrichment
        print("Re-running enrichment with updated merchant rules...")
        enriched_count = await enrich_transactions(conn, user_id, upload_id=None)
        print(f"Enriched {enriched_count} transactions")
        
        # 4. Show sample of enriched transactions
        print("\nSample of enriched transactions:")
        print("-" * 80)
        samples = await conn.fetch("""
            SELECT 
                v.txn_date,
                COALESCE(v.merchant_name_norm, 'Unknown') AS merchant,
                COALESCE(dc.category_name, v.category_code) AS category,
                COALESCE(ds.subcategory_name, v.subcategory_code) AS subcategory,
                v.amount,
                v.direction
            FROM spendsense.vw_txn_effective v
            LEFT JOIN spendsense.dim_category dc ON dc.category_code = v.category_code
            LEFT JOIN spendsense.dim_subcategory ds ON ds.subcategory_code = v.subcategory_code
            WHERE v.user_id = $1
            ORDER BY v.txn_date DESC
            LIMIT 10
        """, user_id)
        
        for row in samples:
            subcat = row['subcategory'] or '—'
            direction = '✓' if row['direction'] == 'credit' else '✗'
            print(f"  {row['txn_date']} | {row['merchant'][:30]:30} | {row['category']:20} | {subcat:30} | {direction} ₹{row['amount']}")
        
        print("\n" + "=" * 80)
        print("Re-enrichment complete!")
        print("=" * 80)
        
    finally:
        await conn.close()


if __name__ == "__main__":
    user_id = None
    
    # Support both --user=UUID and positional argument
    for arg in sys.argv[1:]:
        if arg.startswith('--user='):
            user_id = arg.split('=', 1)[1]
            break
        elif not arg.startswith('--'):
            user_id = arg
            break
    
    if not user_id:
        print("Usage: python scripts/re_enrich_user.py <user_id>")
        print("   or: python scripts/re_enrich_user.py --user=<user_id>")
        print("\nTo find your user_id, check your Supabase auth.users table or")
        print("look at the user_id in your transaction data.")
        sys.exit(1)
    
    asyncio.run(re_enrich_user(user_id))

