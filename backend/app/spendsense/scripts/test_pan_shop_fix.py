#!/usr/bin/env python3
"""
Quick test script to re-enrich just the pan shop transactions that are transfers_out
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
    exit(1)


async def test_pan_shop_fix():
    """Delete and re-enrich only pan shop transactions that are transfers_out."""
    conn = await asyncpg.connect(
        POSTGRES_URL,
        statement_cache_size=0,
        command_timeout=60
    )
    
    try:
        print("=" * 80)
        print("Testing pan shop fix - re-enriching transfers_out pan shop transactions")
        print("=" * 80)
        
        # Find pan shop transactions that are transfers_out
        print("\n1. Finding pan shop transactions categorized as transfers_out...")
        problem_txns = await conn.fetch("""
            SELECT DISTINCT
                f.user_id,
                tp.parsed_id,
                f.merchant_name_norm,
                tp.counterparty_name,
                f.description,
                f.txn_date
            FROM spendsense.txn_fact f
            JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
            JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
            WHERE (LOWER(COALESCE(f.merchant_name_norm, '')) LIKE '%pan%'
               OR LOWER(COALESCE(tp.counterparty_name, '')) LIKE '%pan%'
               OR LOWER(COALESCE(f.description, '')) LIKE '%pan%')
              AND te.category_id = 'transfers_out'
            ORDER BY f.txn_date DESC
        """)
        
        print(f"   Found {len(problem_txns)} pan shop transactions incorrectly categorized")
        
        if len(problem_txns) == 0:
            print("   No problem transactions found. All pan shop transactions are correctly categorized!")
            return
        
        # Show what we found
        for txn in problem_txns[:5]:
            merchant = txn['merchant_name_norm'] or txn['counterparty_name'] or 'N/A'
            print(f"   - {merchant[:40]}")
        
        # Delete enriched records for these transactions
        print("\n2. Deleting enriched records for these transactions...")
        parsed_ids = [row['parsed_id'] for row in problem_txns]
        # Use IN clause with tuple
        placeholders = ','.join([f"${i+1}" for i in range(len(parsed_ids))])
        deleted = await conn.execute(
            f"DELETE FROM spendsense.txn_enriched WHERE parsed_id IN ({placeholders})",
            *parsed_ids
        )
        print(f"   ✓ Deleted {deleted.split()[-1]} enriched records")
        
        # Get user_id (should be same for all)
        user_id = problem_txns[0]['user_id']
        print(f"\n3. Re-enriching transactions for user {user_id}...")
        
        # Re-enrich (this will only process unmatched transactions)
        enriched_count = await enrich_transactions(conn, str(user_id), upload_id=None)
        print(f"   ✓ Re-enriched {enriched_count} transactions")
        
        # Check results
        print("\n4. Verifying fix...")
        placeholders = ','.join([f"${i+1}" for i in range(len(parsed_ids))])
        fixed = await conn.fetch(
            f"""
            SELECT 
                te.category_id,
                te.subcategory_id,
                COUNT(*) as count
            FROM spendsense.txn_enriched te
            WHERE te.parsed_id IN ({placeholders})
            GROUP BY te.category_id, te.subcategory_id
            """,
            *parsed_ids
        )
        
        print("\n   Results:")
        for row in fixed:
            print(f"   - {row['category_id']}/{row['subcategory_id']}: {row['count']} transactions")
        
        # Check if any are still transfers_out
        still_wrong = await conn.fetchval(
            f"""
            SELECT COUNT(*)
            FROM spendsense.txn_enriched te
            WHERE te.parsed_id IN ({placeholders})
              AND te.category_id = 'transfers_out'
            """,
            *parsed_ids
        )
        
        if still_wrong == 0:
            print("\n   ✅ SUCCESS! All pan shop transactions are now correctly categorized!")
        else:
            print(f"\n   ⚠️  {still_wrong} transactions are still transfers_out (may need further investigation)")
        
        print("\n" + "=" * 80)
        
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(test_pan_shop_fix())

