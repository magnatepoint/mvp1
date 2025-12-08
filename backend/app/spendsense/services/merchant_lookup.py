"""
Merchant lookup service for checking dim_merchant and merchant_alias.

This is the first layer of categorization - if we know the brand, trust the brand.
Everything else becomes P2P transfer by default.
"""

import asyncpg
import logging
from typing import Optional, Tuple

logger = logging.getLogger(__name__)


async def lookup_merchant_category(
    conn: asyncpg.Connection,
    merchant_normalized: str,
) -> Tuple[Optional[str], Optional[str]]:
    """
    Look up category and subcategory from dim_merchant + merchant_alias.
    
    This is the strongest source of truth - if we know the brand, trust it.
    
    Args:
        conn: Database connection
        merchant_normalized: Normalized merchant name (lowercase, trimmed)
        
    Returns:
        Tuple of (category_code, subcategory_code) or (None, None) if not found
    """
    if not merchant_normalized:
        return None, None
    
    try:
        row = await conn.fetchrow(
            """
            SELECT m.category_code, m.subcategory_code
            FROM spendsense.dim_merchant m
            LEFT JOIN spendsense.merchant_alias a
                   ON a.merchant_id = m.merchant_id
            WHERE m.active = TRUE
              AND (
                   LOWER(m.normalized_name) = $1
                OR LOWER(a.normalized_alias) = $1
              )
            LIMIT 1
            """,
            merchant_normalized.lower().strip(),
        )
        
        if row:
            category_code = row['category_code']
            subcategory_code = row['subcategory_code']
            logger.debug(
                f"[MERCHANT LOOKUP] Found in dim_merchant: {merchant_normalized} → "
                f"{category_code}/{subcategory_code}"
            )
            return category_code, subcategory_code
        
        return None, None
        
    except Exception as e:
        logger.error(f"Error looking up merchant {merchant_normalized}: {e}")
        return None, None

