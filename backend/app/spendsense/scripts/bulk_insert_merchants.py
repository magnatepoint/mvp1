#!/usr/bin/env python3
"""
Bulk Insert Merchants + Aliases Script

This script allows bulk insertion of merchants and their aliases into dim_merchant
and merchant_alias tables. Useful for adding new merchants programmatically.

Usage:
    python -m app.spendsense.scripts.bulk_insert_merchants --file merchants.json
    python -m app.spendsense.scripts.bulk_insert_merchants --merchant-code swiggy --name Swiggy --keywords swiggy,instamart
"""

import argparse
import asyncio
import json
import logging
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import asyncpg
from dotenv import load_dotenv

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def insert_merchant(
    conn: asyncpg.Connection,
    merchant_code: str,
    merchant_name: str,
    normalized_name: str,
    brand_keywords: List[str],
    category_code: str,
    subcategory_code: Optional[str] = None,
    merchant_type: Optional[str] = None,
    website: Optional[str] = None,
    country_code: str = "IN",
    active: bool = True,
) -> Optional[str]:
    """Insert a merchant into dim_merchant and return merchant_id."""
    try:
        merchant_id = await conn.fetchval(
            """
            INSERT INTO spendsense.dim_merchant (
                merchant_code, merchant_name, normalized_name, brand_keywords,
                category_code, subcategory_code, merchant_type, website,
                country_code, active
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            ON CONFLICT (merchant_code) DO UPDATE
            SET merchant_name = EXCLUDED.merchant_name,
                normalized_name = EXCLUDED.normalized_name,
                brand_keywords = EXCLUDED.brand_keywords,
                category_code = EXCLUDED.category_code,
                subcategory_code = EXCLUDED.subcategory_code,
                merchant_type = EXCLUDED.merchant_type,
                website = EXCLUDED.website,
                updated_at = NOW()
            RETURNING merchant_id::TEXT
            """,
            merchant_code,
            merchant_name,
            normalized_name,
            brand_keywords,
            category_code,
            subcategory_code,
            merchant_type,
            website,
            country_code,
            active,
        )
        return merchant_id
    except Exception as e:
        logger.error(f"Error inserting merchant {merchant_code}: {e}")
        return None


async def insert_aliases(
    conn: asyncpg.Connection,
    merchant_id: str,
    aliases: List[str],
) -> int:
    """Insert aliases for a merchant into merchant_alias table."""
    if not aliases:
        return 0
    
    inserted = 0
    for alias in aliases:
        try:
            await conn.execute(
                """
                INSERT INTO spendsense.merchant_alias (merchant_id, alias, normalized_alias)
                VALUES ($1::UUID, $2, LOWER($2))
                ON CONFLICT (merchant_id, normalized_alias) DO NOTHING
                """,
                merchant_id,
                alias.strip(),
            )
            inserted += 1
        except Exception as e:
            logger.warning(f"Error inserting alias '{alias}' for merchant {merchant_id}: {e}")
    
    return inserted


async def bulk_insert_from_file(
    conn: asyncpg.Connection,
    file_path: Path,
) -> Dict[str, Any]:
    """Bulk insert merchants from JSON file."""
    with open(file_path, "r") as f:
        merchants = json.load(f)
    
    results = {
        "total": len(merchants),
        "inserted": 0,
        "updated": 0,
        "failed": 0,
        "aliases_inserted": 0,
    }
    
    for merchant in merchants:
        merchant_code = merchant.get("merchant_code")
        if not merchant_code:
            logger.warning(f"Skipping merchant without merchant_code: {merchant}")
            results["failed"] += 1
            continue
        
        # Insert merchant
        merchant_id = await insert_merchant(
            conn,
            merchant_code=merchant_code,
            merchant_name=merchant.get("merchant_name", merchant_code.title()),
            normalized_name=merchant.get("normalized_name", merchant_code.lower()),
            brand_keywords=merchant.get("brand_keywords", [merchant_code]),
            category_code=merchant.get("category_code", "shopping"),
            subcategory_code=merchant.get("subcategory_code"),
            merchant_type=merchant.get("merchant_type", "online"),
            website=merchant.get("website"),
            country_code=merchant.get("country_code", "IN"),
            active=merchant.get("active", True),
        )
        
        if merchant_id:
            # Check if it was an insert or update
            existing = await conn.fetchval(
                "SELECT merchant_id FROM spendsense.dim_merchant WHERE merchant_code = $1",
                merchant_code,
            )
            if existing:
                results["updated"] += 1
            else:
                results["inserted"] += 1
            
            # Insert aliases
            aliases = merchant.get("aliases", []) + merchant.get("brand_keywords", [])
            aliases_count = await insert_aliases(conn, merchant_id, aliases)
            results["aliases_inserted"] += aliases_count
        else:
            results["failed"] += 1
    
    return results


async def insert_single_merchant(
    conn: asyncpg.Connection,
    merchant_code: str,
    merchant_name: str,
    keywords: List[str],
    category_code: str,
    subcategory_code: Optional[str] = None,
) -> Dict[str, Any]:
    """Insert a single merchant from command line arguments."""
    normalized_name = merchant_code.lower()
    
    merchant_id = await insert_merchant(
        conn,
        merchant_code=merchant_code,
        merchant_name=merchant_name,
        normalized_name=normalized_name,
        brand_keywords=keywords,
        category_code=category_code,
        subcategory_code=subcategory_code,
    )
    
    if merchant_id:
        aliases_count = await insert_aliases(conn, merchant_id, keywords)
        return {
            "merchant_id": merchant_id,
            "aliases_inserted": aliases_count,
        }
    else:
        return {"error": "Failed to insert merchant"}


async def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Bulk insert merchants and aliases")
    parser.add_argument(
        "--file",
        type=Path,
        help="JSON file containing merchants array",
    )
    parser.add_argument(
        "--merchant-code",
        help="Merchant code (for single insert)",
    )
    parser.add_argument(
        "--name",
        help="Merchant name (for single insert)",
    )
    parser.add_argument(
        "--keywords",
        help="Comma-separated keywords (for single insert)",
    )
    parser.add_argument(
        "--category",
        default="shopping",
        help="Category code (default: shopping)",
    )
    parser.add_argument(
        "--subcategory",
        help="Subcategory code (optional)",
    )
    parser.add_argument(
        "--postgres-url",
        help="PostgreSQL connection URL (overrides .env)",
    )
    
    args = parser.parse_args()
    
    # Load environment
    load_dotenv()
    
    # Get database connection
    import os
    postgres_url = args.postgres_url or os.getenv("POSTGRES_URL", "")
    if not postgres_url:
        logger.error("POSTGRES_URL not found. Set it in .env or use --postgres-url")
        return 1
    
    conn = await asyncpg.connect(postgres_url)
    
    try:
        if args.file:
            # Bulk insert from file
            logger.info(f"Bulk inserting merchants from {args.file}")
            results = await bulk_insert_from_file(conn, args.file)
            logger.info(f"Results: {results}")
        elif args.merchant_code and args.name and args.keywords:
            # Single insert
            keywords = [k.strip() for k in args.keywords.split(",")]
            result = await insert_single_merchant(
                conn,
                merchant_code=args.merchant_code,
                merchant_name=args.name,
                keywords=keywords,
                category_code=args.category,
                subcategory_code=args.subcategory,
            )
            logger.info(f"Result: {result}")
        else:
            parser.print_help()
            return 1
        
        return 0
    finally:
        await conn.close()


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)

