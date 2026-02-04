#!/usr/bin/env python3
"""
Normalize merchant_rules.merchant_name_norm to lowercase for consistent matching.

This script ensures all merchant_rules have lowercase merchant_name_norm values
to match the new normalization standard.
"""

import asyncio
import asyncpg
import sys
from pathlib import Path

# Add backend to path
backend_path = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(backend_path))

from app.core.config import get_settings


async def normalize_merchant_rules():
    """Normalize all merchant_rules.merchant_name_norm to lowercase."""
    settings = get_settings()
    
    conn = await asyncpg.connect(
        str(settings.postgres_dsn),
        statement_cache_size=0,
        command_timeout=300
    )
    
    try:
        # Check how many rules need normalization
        count_query = """
            SELECT COUNT(*) 
            FROM spendsense.merchant_rules
            WHERE merchant_name_norm IS NOT NULL
              AND merchant_name_norm != LOWER(TRIM(merchant_name_norm))
        """
        count = await conn.fetchval(count_query)
        
        if count == 0:
            print("✓ All merchant_rules already normalized (lowercase)")
            return
        
        print(f"Found {count} merchant_rules that need normalization")
        
        # Show sample of rules that will be updated
        sample_query = """
            SELECT rule_id, merchant_name_norm, category_code, subcategory_code
            FROM spendsense.merchant_rules
            WHERE merchant_name_norm IS NOT NULL
              AND merchant_name_norm != LOWER(TRIM(merchant_name_norm))
            LIMIT 5
        """
        samples = await conn.fetch(sample_query)
        
        print("\nSample rules that will be normalized:")
        for row in samples:
            old = row['merchant_name_norm']
            new = old.lower().strip() if old else ''
            print(f"  {old} → {new} ({row['category_code']}/{row['subcategory_code']})")
        
        # Update all rules to lowercase
        update_query = """
            UPDATE spendsense.merchant_rules
            SET merchant_name_norm = LOWER(TRIM(merchant_name_norm))
            WHERE merchant_name_norm IS NOT NULL
              AND merchant_name_norm != LOWER(TRIM(merchant_name_norm))
        """
        updated = await conn.execute(update_query)
        
        print(f"\n✓ Normalized {updated.split()[-1]} merchant_rules")
        
        # Verify
        remaining = await conn.fetchval(count_query)
        if remaining == 0:
            print("✓ All merchant_rules are now normalized")
        else:
            print(f"⚠️  {remaining} rules still need normalization")
    
    finally:
        await conn.close()


async def main():
    await normalize_merchant_rules()


if __name__ == "__main__":
    asyncio.run(main())
