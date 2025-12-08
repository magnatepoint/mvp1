#!/usr/bin/env python3
"""
Taxonomy Diagnostic Script
Run this to check which codes exist in dim_subcategory and identify issues
before running migration 030_fix_merchant_rules_taxonomy.sql
"""

import asyncio
import asyncpg
from pathlib import Path
import sys

# Add backend to path
backend_path = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(backend_path))

from app.core.config import get_settings


async def check_taxonomy():
    """Check taxonomy alignment between merchant_rules and dim_subcategory."""
    settings = get_settings()
    
    conn = await asyncpg.connect(
        str(settings.postgres_dsn),
        statement_cache_size=0
    )
    
    try:
        print("=" * 80)
        print("TAXONOMY DIAGNOSTIC REPORT")
        print("=" * 80)
        print()
        
        # 1. List all subcategories
        print("1. EXISTING SUBCATEGORIES:")
        print("-" * 80)
        subcats = await conn.fetch("""
            SELECT category_code, subcategory_code, subcategory_name, active
            FROM spendsense.dim_subcategory
            ORDER BY category_code, subcategory_code
        """)
        if subcats:
            for row in subcats:
                status = "✓" if row['active'] else "✗"
                print(f"  {status} {row['category_code']:20} / {row['subcategory_code']:30} - {row['subcategory_name']}")
        else:
            print("  No subcategories found!")
        print()
        
        # 2. List all categories
        print("2. EXISTING CATEGORIES:")
        print("-" * 80)
        cats = await conn.fetch("""
            SELECT category_code, category_name, txn_type, active
            FROM spendsense.dim_category
            ORDER BY category_code
        """)
        if cats:
            for row in cats:
                status = "✓" if row['active'] else "✗"
                print(f"  {status} {row['category_code']:20} - {row['category_name']:30} ({row['txn_type']})")
        else:
            print("  No categories found!")
        print()
        
        # 3. Merchant rules with invalid codes
        print("3. MERCHANT RULES WITH INVALID CODES:")
        print("-" * 80)
        invalid_rules = await conn.fetch("""
            SELECT 
                mr.rule_id,
                mr.priority,
                mr.pattern_regex,
                mr.category_code AS rule_category,
                mr.subcategory_code AS rule_subcategory,
                mr.active,
                CASE 
                    WHEN mr.category_code NOT IN (SELECT category_code FROM spendsense.dim_category) 
                        THEN 'INVALID CATEGORY'
                    WHEN mr.subcategory_code IS NOT NULL 
                         AND mr.subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory)
                        THEN 'INVALID SUBCATEGORY'
                    ELSE 'OK'
                END AS issue
            FROM spendsense.merchant_rules mr
            WHERE mr.active = true
              AND (
                  mr.category_code NOT IN (SELECT category_code FROM spendsense.dim_category)
                  OR (mr.subcategory_code IS NOT NULL 
                      AND mr.subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory))
              )
            ORDER BY mr.category_code, mr.subcategory_code
        """)
        if invalid_rules:
            for row in invalid_rules:
                print(f"  ✗ {row['rule_category']}/{row['rule_subcategory']} - {row['issue']}")
                print(f"    Pattern: {row['pattern_regex'][:60]}...")
        else:
            print("  ✓ All active merchant rules have valid codes!")
        print()
        
        # 4. Summary statistics
        print("4. SUMMARY STATISTICS:")
        print("-" * 80)
        stats = await conn.fetchrow("""
            SELECT 
                (SELECT COUNT(*) FROM spendsense.merchant_rules WHERE active = true) AS total_active_rules,
                (SELECT COUNT(*) FROM spendsense.merchant_rules 
                 WHERE active = true 
                   AND category_code NOT IN (SELECT category_code FROM spendsense.dim_category)) AS rules_invalid_category,
                (SELECT COUNT(*) FROM spendsense.merchant_rules 
                 WHERE active = true 
                   AND subcategory_code IS NOT NULL
                   AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory)) AS rules_invalid_subcategory,
                (SELECT COUNT(*) FROM spendsense.txn_enriched 
                 WHERE category_code NOT IN (SELECT category_code FROM spendsense.dim_category)) AS enriched_invalid_category,
                (SELECT COUNT(*) FROM spendsense.txn_enriched 
                 WHERE subcategory_code IS NOT NULL
                   AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory)) AS enriched_invalid_subcategory
        """)
        print(f"  Total active merchant rules: {stats['total_active_rules']}")
        print(f"  Rules with invalid category: {stats['rules_invalid_category']}")
        print(f"  Rules with invalid subcategory: {stats['rules_invalid_subcategory']}")
        print(f"  Enriched transactions with invalid category: {stats['enriched_invalid_category']}")
        print(f"  Enriched transactions with invalid subcategory: {stats['enriched_invalid_subcategory']}")
        print()
        
        # 5. Codes that merchant rules are trying to use
        print("5. MERCHANT RULES: CODES IN USE:")
        print("-" * 80)
        rule_codes = await conn.fetch("""
            SELECT DISTINCT
                mr.category_code,
                mr.subcategory_code,
                CASE 
                    WHEN mr.category_code IN (SELECT category_code FROM spendsense.dim_category) 
                        THEN 'EXISTS'
                    ELSE 'MISSING'
                END AS category_status,
                CASE 
                    WHEN mr.subcategory_code IS NULL 
                        THEN 'NULL'
                    WHEN mr.subcategory_code IN (SELECT subcategory_code FROM spendsense.dim_subcategory)
                        THEN 'EXISTS'
                    ELSE 'MISSING'
                END AS subcategory_status
            FROM spendsense.merchant_rules mr
            WHERE mr.active = true
            ORDER BY mr.category_code, mr.subcategory_code
        """)
        if rule_codes:
            for row in rule_codes:
                cat_status = "✓" if row['category_status'] == 'EXISTS' else "✗"
                subcat_status = "✓" if row['subcategory_status'] == 'EXISTS' else ("—" if row['subcategory_status'] == 'NULL' else "✗")
                print(f"  {cat_status} {row['category_code']:20} / {subcat_status} {row['subcategory_code'] or '(NULL)':30}")
        print()
        
        # 6. Enriched transactions with invalid codes
        print("6. ENRICHED TRANSACTIONS WITH INVALID CODES:")
        print("-" * 80)
        invalid_enriched = await conn.fetch("""
            SELECT 
                e.category_id AS enriched_category,
                e.subcategory_id AS enriched_subcategory,
                COUNT(*) AS transaction_count,
                CASE 
                    WHEN e.category_id NOT IN (SELECT category_code FROM spendsense.dim_category) 
                        THEN 'INVALID CATEGORY'
                    WHEN e.subcategory_id IS NOT NULL 
                         AND e.subcategory_id NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory)
                        THEN 'INVALID SUBCATEGORY'
                    ELSE 'OK'
                END AS issue
            FROM spendsense.txn_enriched e
            WHERE (
                e.category_id NOT IN (SELECT category_code FROM spendsense.dim_category)
                OR (e.subcategory_id IS NOT NULL 
                    AND e.subcategory_id NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory))
            )
            GROUP BY e.category_id, e.subcategory_id
            ORDER BY transaction_count DESC
            LIMIT 20
        """)
        if invalid_enriched:
            for row in invalid_enriched:
                print(f"  ✗ {row['enriched_category']}/{row['enriched_subcategory']} - {row['issue']} ({row['transaction_count']} transactions)")
        else:
            print("  ✓ All enriched transactions have valid codes!")
        print()
        
        print("=" * 80)
        print("DIAGNOSTIC COMPLETE")
        print("=" * 80)
        print()
        print("Next steps:")
        print("1. Review the invalid codes above")
        print("2. If codes are missing, either:")
        print("   a) Add them to dim_subcategory, OR")
        print("   b) Run migration 030_fix_merchant_rules_taxonomy.sql to map to existing codes")
        print("3. After migration, re-run enrichment for affected users")
        
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(check_taxonomy())

