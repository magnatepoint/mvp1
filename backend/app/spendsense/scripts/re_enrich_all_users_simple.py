#!/usr/bin/env python3
"""
Re-enrich transactions for all users - Simple version
Uses asyncpg directly to avoid app import issues
"""

import asyncio
import asyncpg
import os
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables
backend_dir = Path(__file__).parent.parent.parent.parent
env_file = backend_dir / ".env"
if env_file.exists():
    load_dotenv(env_file)

# Get database URL
POSTGRES_URL = os.getenv("POSTGRES_URL")
if not POSTGRES_URL:
    print("Error: POSTGRES_URL not found in environment variables")
    print("Please set POSTGRES_URL in your .env file")
    exit(1)

# Import enrichment function (this will work if dependencies are installed)
try:
    import sys
    sys.path.insert(0, str(backend_dir))
    from app.spendsense.etl.pipeline import enrich_transactions
except ImportError as e:
    print(f"Error importing enrichment module: {e}")
    print("Please ensure all dependencies are installed:")
    print("  pip install -r requirements.txt")
    exit(1)


async def re_enrich_all_users():
    """Re-enrich transactions for all users."""
    conn = await asyncpg.connect(
        POSTGRES_URL,
        statement_cache_size=0,
        command_timeout=600  # 10 minutes timeout
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
        await conn.execute("""
            DELETE FROM spendsense.txn_enriched
        """)
        print("Deleted all enriched records")
        
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
                import traceback
                traceback.print_exc()
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
        exit(0)
    
    asyncio.run(re_enrich_all_users())

