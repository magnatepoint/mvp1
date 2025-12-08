#!/usr/bin/env python3
"""
Re-enrich transactions for all users
Deletes existing enriched records and re-runs enrichment with updated merchant rules
"""

import asyncio
import asyncpg
import sys
from pathlib import Path

# Add backend to path
backend_path = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(backend_path))

# Import config directly to avoid app.__init__ import
import importlib.util
spec = importlib.util.spec_from_file_location("config", backend_path / "app" / "core" / "config.py")
config_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config_module)
get_settings = config_module.get_settings

# Import pipeline
from app.spendsense.etl.pipeline import enrich_transactions


async def re_enrich_all_users():
    """Re-enrich transactions for all users."""
    settings = get_settings()
    
    conn = await asyncpg.connect(
        str(settings.postgres_dsn),
        statement_cache_size=0,
        command_timeout=600  # 10 minutes timeout for all users
    )
    
    try:
        print("=" * 80)
        print("Re-enriching transactions for ALL users")
        print("=" * 80)
        
        # 1. Get all user IDs that have transactions
        print("\nFetching all user IDs with transactions...")
        user_ids = await conn.fetch("""
            SELECT DISTINCT user_id 
            FROM spendsense.txn_fact
            ORDER BY user_id
        """)
        
        total_users = len(user_ids)
        print(f"Found {total_users} users with transactions")
        
        if total_users == 0:
            print("No users found. Exiting.")
            return
        
        # 2. Count total existing enriched records
        total_existing = await conn.fetchval("""
            SELECT COUNT(*) 
            FROM spendsense.txn_enriched
        """)
        print(f"Total existing enriched transactions: {total_existing}")
        
        # 3. Delete all existing enriched records
        print("\nDeleting all existing enriched records...")
        deleted = await conn.execute("""
            DELETE FROM spendsense.txn_enriched
        """)
        print(f"Deleted all enriched records")
        
        # 4. Re-enrich for each user
        print("\n" + "=" * 80)
        print("Re-enriching transactions for each user...")
        print("=" * 80)
        
        total_enriched = 0
        for idx, row in enumerate(user_ids, 1):
            user_id = row['user_id']
            print(f"\n[{idx}/{total_users}] Processing user: {user_id}")
            print("-" * 80)
            
            try:
                enriched_count = await enrich_transactions(conn, str(user_id), upload_id=None)
                total_enriched += enriched_count
                print(f"✓ Enriched {enriched_count} transactions for user {user_id}")
            except Exception as e:
                print(f"✗ Error enriching transactions for user {user_id}: {e}")
                continue
        
        print("\n" + "=" * 80)
        print("Re-enrichment complete!")
        print(f"Total users processed: {total_users}")
        print(f"Total transactions enriched: {total_enriched}")
        print("=" * 80)
        
    finally:
        await conn.close()


if __name__ == "__main__":
    print("This will re-enrich transactions for ALL users.")
    print("This may take a while depending on the number of users and transactions.")
    response = input("Continue? (yes/no): ")
    
    if response.lower() not in ['yes', 'y']:
        print("Cancelled.")
        sys.exit(0)
    
    asyncio.run(re_enrich_all_users())

