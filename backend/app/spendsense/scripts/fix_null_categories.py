#!/usr/bin/env python3
"""
Fix transactions with NULL category_id or subcategory_id in txn_enriched.

This script finds and fixes enriched transactions that have NULL category or subcategory,
which can happen if merchant_rules had NULL values or inference failed.
"""

import asyncio
import asyncpg
import logging
import sys
from pathlib import Path

# Add backend to path
backend_path = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(backend_path))

from app.core.config import get_settings
from app.spendsense.etl.pipeline import enrich_transactions

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def fix_null_categories(user_id: str | None = None, upload_id: str | None = None):
    """Fix NULL category_id or subcategory_id in txn_enriched."""
    
    settings = get_settings()
    
    # Connect to database
    conn = await asyncpg.connect(
        str(settings.postgres_dsn),
        statement_cache_size=0,
        command_timeout=300
    )
    
    try:
        # Find transactions with NULL category or subcategory
        if upload_id:
            query = """
                SELECT DISTINCT te.parsed_id, te.category_id, te.subcategory_id, f.user_id, f.upload_id
                FROM spendsense.txn_enriched te
                JOIN spendsense.txn_parsed tp ON tp.parsed_id = te.parsed_id
                JOIN spendsense.txn_fact f ON f.txn_id = tp.fact_txn_id
                WHERE f.upload_id = $1
                    AND (te.category_id IS NULL OR te.subcategory_id IS NULL)
            """
            rows = await conn.fetch(query, upload_id)
        elif user_id:
            query = """
                SELECT DISTINCT te.parsed_id, te.category_id, te.subcategory_id, f.user_id, f.upload_id
                FROM spendsense.txn_enriched te
                JOIN spendsense.txn_parsed tp ON tp.parsed_id = te.parsed_id
                JOIN spendsense.txn_fact f ON f.txn_id = tp.fact_txn_id
                WHERE f.user_id = $1
                    AND (te.category_id IS NULL OR te.subcategory_id IS NULL)
            """
            rows = await conn.fetch(query, user_id)
        else:
            query = """
                SELECT DISTINCT te.parsed_id, te.category_id, te.subcategory_id, f.user_id, f.upload_id
                FROM spendsense.txn_enriched te
                JOIN spendsense.txn_parsed tp ON tp.parsed_id = te.parsed_id
                JOIN spendsense.txn_fact f ON f.txn_id = tp.fact_txn_id
                WHERE te.category_id IS NULL OR te.subcategory_id IS NULL
            """
            rows = await conn.fetch(query)
        
        if not rows:
            logger.info("No transactions with NULL category or subcategory found.")
            return
        
        logger.info(f"Found {len(rows)} transactions with NULL category or subcategory")
        
        # Delete these enriched records so they can be re-enriched
        parsed_ids = [row['parsed_id'] for row in rows]
        logger.info(f"Deleting {len(parsed_ids)} enriched records to allow re-enrichment...")
        
        # Delete using IN clause with proper UUID handling
        if parsed_ids:
            # Use executemany for better compatibility, or build a proper IN clause
            placeholders = ','.join(f'${i+1}' for i in range(len(parsed_ids)))
            await conn.execute(
                f"""
                DELETE FROM spendsense.txn_enriched
                WHERE parsed_id IN ({placeholders})
                """,
                *parsed_ids
            )
        
        logger.info(f"Deleted {len(parsed_ids)} enriched records")
        
        # Group by user_id and upload_id to re-enrich efficiently
        user_batches = {}
        for row in rows:
            key = (row['user_id'], row['upload_id'])
            if key not in user_batches:
                user_batches[key] = []
            user_batches[key].append(row['parsed_id'])
        
        total_fixed = 0
        for (uid, upload_id), pids in user_batches.items():
            logger.info(f"Re-enriching {len(pids)} transactions for user {uid}, batch {upload_id}")
            try:
                if upload_id:
                    count = await enrich_transactions(conn, str(uid), upload_id)
                else:
                    count = await enrich_transactions(conn, str(uid), None)
                total_fixed += count
                logger.info(f"  ✓ Re-enriched {count} transactions")
            except Exception as e:
                logger.error(f"  ✗ Error re-enriching for user {uid}, batch {upload_id}: {e}", exc_info=True)
        
        logger.info(f"Fixed {total_fixed} transactions total")
        
        # Verify fix
        if upload_id:
            verify_query = """
                SELECT COUNT(*) 
                FROM spendsense.txn_enriched te
                JOIN spendsense.txn_parsed tp ON tp.parsed_id = te.parsed_id
                JOIN spendsense.txn_fact f ON f.txn_id = tp.fact_txn_id
                WHERE f.upload_id = $1
                    AND (te.category_id IS NULL OR te.subcategory_id IS NULL)
            """
            remaining = await conn.fetchval(verify_query, upload_id)
        elif user_id:
            verify_query = """
                SELECT COUNT(*) 
                FROM spendsense.txn_enriched te
                JOIN spendsense.txn_parsed tp ON tp.parsed_id = te.parsed_id
                JOIN spendsense.txn_fact f ON f.txn_id = tp.fact_txn_id
                WHERE f.user_id = $1
                    AND (te.category_id IS NULL OR te.subcategory_id IS NULL)
            """
            remaining = await conn.fetchval(verify_query, user_id)
        else:
            verify_query = """
                SELECT COUNT(*) 
                FROM spendsense.txn_enriched
                WHERE category_id IS NULL OR subcategory_id IS NULL
            """
            remaining = await conn.fetchval(verify_query)
        
        if remaining == 0:
            logger.info("✅ All NULL categories/subcategories have been fixed!")
        else:
            logger.warning(f"⚠️  {remaining} transactions still have NULL category or subcategory")
    
    finally:
        await conn.close()


async def main():
    import sys
    
    user_id = None
    upload_id = None
    
    if len(sys.argv) > 1:
        if sys.argv[1].startswith('--user='):
            user_id = sys.argv[1].split('=')[1]
        elif sys.argv[1].startswith('--upload='):
            upload_id = sys.argv[1].split('=')[1]
        else:
            print("Usage: python fix_null_categories.py [--user=USER_ID] [--upload=UPLOAD_ID]")
            print("  --user=USER_ID    Fix for specific user only")
            print("  --upload=UPLOAD_ID Fix for specific upload batch only")
            print("  (no args)         Fix for all users")
            return
    
    await fix_null_categories(user_id, upload_id)


if __name__ == "__main__":
    asyncio.run(main())
