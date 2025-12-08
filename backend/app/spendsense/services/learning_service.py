"""
Learning service for creating merchant rules from user corrections.

When a user corrects a transaction category, we learn from it and create
a merchant rule so future transactions with the same merchant are automatically
categorized correctly.
"""

import asyncpg
import logging
import re
from typing import Optional

logger = logging.getLogger(__name__)


async def learn_from_edit(
    conn: asyncpg.Connection,
    user_id: str,
    merchant_name: str,
    description: str,
    category_code: str,
    subcategory_code: Optional[str],
    txn_id: str,
) -> Optional[str]:
    """
    Learn from user edit and create a merchant rule.
    
    When a user corrects a transaction category, we create a merchant rule
    with high priority so future transactions with the same merchant are
    automatically categorized correctly.
    
    Args:
        conn: Database connection
        user_id: User ID who made the correction
        merchant_name: Normalized merchant name
        description: Transaction description
        category_code: Corrected category code
        subcategory_code: Corrected subcategory code (optional)
        txn_id: Transaction ID that was corrected
        
    Returns:
        rule_id (UUID as string) if rule was created, None otherwise
    """
    if not merchant_name or not category_code:
        return None
    
    # Normalize merchant name
    merchant_normalized = merchant_name.lower().strip()
    if not merchant_normalized:
        return None
    
    try:
        # Check if a rule already exists for this merchant
        existing = await conn.fetchrow(
            """
            SELECT rule_id, category_code, subcategory_code
            FROM spendsense.merchant_rules
            WHERE merchant_name_norm = $1
              AND active = TRUE
            LIMIT 1
            """,
            merchant_normalized,
        )
        
        if existing:
            # Rule exists - check if it matches
            if (existing['category_code'] == category_code and 
                existing['subcategory_code'] == subcategory_code):
                logger.debug(f"Rule already exists for {merchant_normalized} → {category_code}")
                return str(existing['rule_id'])
            else:
                # Rule exists but with different category - update it
                logger.info(
                    f"Updating existing rule for {merchant_normalized}: "
                    f"{existing['category_code']} → {category_code}"
                )
                await conn.execute(
                    """
                    UPDATE spendsense.merchant_rules
                    SET category_code = $1,
                        subcategory_code = $2,
                        priority = 120,  -- Higher priority for user-learned rules
                        updated_at = NOW()
                    WHERE rule_id = $3
                    """,
                    category_code,
                    subcategory_code,
                    existing['rule_id'],
                )
                return str(existing['rule_id'])
        
        # Create pattern_regex from merchant name
        # Escape special regex characters and create a case-insensitive pattern
        escaped_merchant = re.escape(merchant_normalized)
        pattern_regex = f"(?i).*{escaped_merchant}.*"
        
        # Generate pattern_hash
        pattern_hash_result = await conn.fetchval(
            "SELECT encode(digest($1, 'sha1'), 'hex')",
            pattern_regex,
        )
        
        # Insert new rule with high priority (120 > default 10)
        rule_id = await conn.fetchval(
            """
            INSERT INTO spendsense.merchant_rules (
                merchant_name_norm,
                category_code,
                subcategory_code,
                applies_to,
                priority,
                active,
                source,
                confidence,
                pattern_regex,
                pattern_hash,
                created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW())
            RETURNING rule_id
            """,
            merchant_normalized,
            category_code,
            subcategory_code,
            'merchant',  # applies_to
            120,  # High priority for user-learned rules
            True,  # active
            'user_edit',  # source
            0.95,  # High confidence for user corrections
            pattern_regex,
            pattern_hash_result,
        )
        
        logger.info(
            f"Created merchant rule from user edit: {merchant_normalized} → "
            f"{category_code}/{subcategory_code} (rule_id: {rule_id})"
        )
        
        return str(rule_id)
        
    except Exception as e:
        logger.error(f"Error learning from edit for {merchant_normalized}: {e}", exc_info=True)
        return None

