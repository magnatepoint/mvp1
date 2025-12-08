#!/usr/bin/env python3
"""
Re-enrichment script with Python fallback for unmatched transactions
Uses the actual enrich_transactions function via direct import
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


# Copy the personal name detection function (simplified version)
def _looks_like_personal_name(text: str) -> bool:
    """Check if text looks like a personal name."""
    if not text:
        return False
    
    t = text.lower().strip()
    
    # Strip common UPI/IMPS prefixes
    import re
    t = re.sub(r'(upi|imps|neft|rtgs)[-/]?', '', t, flags=re.IGNORECASE)
    t = re.sub(r'by\s+transfer[-/]?', '', t, flags=re.IGNORECASE)
    t = re.sub(r'/\d{6,}/', '', t)
    t = re.sub(r'\d{6,}', '', t)
    t = re.sub(r'/[a-z0-9-]+/', '', t)
    t = t.strip()
    
    tokens = [w for w in re.split(r'[\s/]+', t) if w]
    ignore_tokens = {
        'int', 'to', 'by', 'transfer', 'upi', 'imps', 'neft', 'rtgs',
        'gpay', 'phonepe', 'paytm', 'google', 'pay', 'wallet',
        'dr', 'cr', 'debit', 'credit', 'out', 'in',
        'hsb', 'cams', 'xx', 'xxx', 'xxxx', 'xxxxx',
    }
    tokens = [w for w in tokens if w not in ignore_tokens and len(w) > 1]
    
    if len(tokens) == 0:
        return False
    
    # Single token must be at least 3 characters
    if len(tokens) == 1:
        return len(tokens[0]) >= 3
    
    # Multiple tokens - likely a name
    if len(tokens) >= 2:
        return True
    
    return False


# Copy the category inference function (simplified)
def _infer_category_from_keywords(text: str, direction: str) -> str:
    """Infer category from keywords."""
    if not text:
        return "transfers_out" if direction == "debit" else "transfers_in"
    
    text_lower = text.lower()
    
    # Check for personal names first
    if _looks_like_personal_name(text_lower):
        return "transfers_out" if direction == "debit" else "transfers_in"
    
    # UPI + personal name = P2P transfer
    if any(k in text_lower for k in ["upi", "imps", "neft", "rtgs", "gpay", "google pay", "phonepe", "paytm"]):
        if _looks_like_personal_name(text_lower):
            return "transfers_out" if direction == "debit" else "transfers_in"
        return "shopping"
    
    # Personal name even without UPI keyword
    if _looks_like_personal_name(text_lower):
        return "transfers_out" if direction == "debit" else "transfers_in"
    
    # Default fallback
    return "transfers_out" if direction == "debit" else "transfers_in"


async def process_unmatched_transactions(conn, user_id):
    """Process unmatched transactions with Python inference."""
    # Fetch unmatched transactions
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
    
    unmatched_rows = await conn.fetch(unmatched_query, user_id)
    inferred_count = 0
    
    print(f"   Processing {len(unmatched_rows)} unmatched transactions...")
    
    for row in unmatched_rows:
        parsed_id = row['parsed_id']
        description = row['description'] or ''
        merchant_norm = row['merchant_name_norm'] or ''
        counterparty = row['counterparty_name'] or ''
        channel = row['channel_type'] or ''
        parsed_dir = row['parsed_direction'] or ''
        fact_dir = row['fact_direction'] or ''
        
        merchant_for_inference = merchant_norm or counterparty or description
        merchant_normalized = merchant_for_inference.lower().strip() if merchant_for_inference else ''
        direction = 'debit' if parsed_dir == 'OUT' or fact_dir == 'debit' else 'credit'
        
        # Check if personal name
        category_code = None
        subcategory_code = None
        confidence = 0.6
        
        if merchant_normalized and _looks_like_personal_name(merchant_normalized):
            category_code = "transfers_out" if direction == "debit" else "transfers_in"
            subcategory_code = "tr_out_wallet" if channel == "UPI" else "tr_out_other" if direction == "debit" else "tr_in_other"
            confidence = 0.95
        else:
            # Use keyword inference
            category_code = _infer_category_from_keywords(
                merchant_for_inference.lower() + " " + description.lower(),
                direction
            )
            
            # Determine subcategory
            if category_code == 'transfers_out':
                subcategory_code = 'tr_out_wallet' if channel == 'UPI' else 'tr_out_other'
            elif category_code == 'transfers_in':
                subcategory_code = 'tr_in_other'
            else:
                subcategory_code = None
        
        # Get txn_type
        txn_type_row = await conn.fetchrow(
            "SELECT txn_type FROM spendsense.dim_category WHERE category_code = $1",
            category_code
        )
        txn_type = txn_type_row['txn_type'] if txn_type_row else 'transfer'
        
        # Insert
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
        except Exception as e:
            print(f"   ✗ Error inserting {parsed_id}: {e}")
    
    return inferred_count


async def re_enrich_all():
    """Re-enrich all users' transactions."""
    conn = await asyncpg.connect(
        POSTGRES_URL,
        statement_cache_size=0,
        command_timeout=600
    )
    
    try:
        print("=" * 80)
        print("Re-enriching ALL transactions with Python fallback")
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
        
        # Re-enrich each user using the actual function
        print("\n4. Re-enriching transactions for each user...")
        print("=" * 80)
        
        # Import here to avoid dependency issues
        try:
            from app.spendsense.etl.pipeline import enrich_transactions
            use_actual_function = True
        except ImportError:
            print("   ⚠ Cannot import enrich_transactions, using SQL-only approach")
            use_actual_function = False
        
        total_enriched = 0
        for idx, row in enumerate(user_ids, 1):
            user_id = str(row['user_id'])
            print(f"\n[{idx}/{total_users}] User: {user_id}")
            
            try:
                if use_actual_function:
                    # Use the actual function which includes Python fallback
                    enriched_count = await enrich_transactions(conn, user_id, upload_id=None)
                    total_enriched += enriched_count
                    print(f"   ✓ Enriched {enriched_count} transactions")
                else:
                    # Fallback: process unmatched manually
                    print("   ⚠ Using manual fallback processing")
                    unmatched_count = await process_unmatched_transactions(conn, user_id)
                    total_enriched += unmatched_count
                    print(f"   ✓ Processed {unmatched_count} unmatched transactions")
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
        
        # Verify
        print("\n5. Verifying results...")
        still_unmatched = await conn.fetchval("""
            SELECT COUNT(*) 
            FROM spendsense.txn_parsed tp
            JOIN spendsense.txn_fact tf ON tp.fact_txn_id = tf.txn_id
            WHERE tf.user_id = $1
            AND NOT EXISTS (
                SELECT 1 FROM spendsense.txn_enriched te 
                WHERE te.parsed_id = tp.parsed_id
            )
        """, user_ids[0]['user_id'] if user_ids else None)
        print(f"   Remaining unmatched: {still_unmatched}")
        
    finally:
        await conn.close()


if __name__ == "__main__":
    print("Starting re-enrichment with Python fallback...")
    asyncio.run(re_enrich_all())

