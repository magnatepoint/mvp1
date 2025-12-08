"""
Diagnostic script to analyze categorization accuracy and identify issues.

This script helps identify:
- Transactions that might be mis-categorized
- Common patterns in wrong categorizations
- Missing merchant rules
- Issues with personal name detection

Usage:
    python3 -m app.spendsense.scripts.analyze_categorization <user_id>
"""

import asyncio
import asyncpg
import logging
import sys
from pathlib import Path
from collections import Counter, defaultdict

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from app.core.config import get_settings
from app.spendsense.services.category_inference import _looks_like_personal_name, _infer_category_from_keywords
from app.spendsense.services.merchant_lookup import lookup_merchant_category

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def analyze_categorization(user_id: str):
    """Analyze categorization for a user and identify issues."""
    
    settings = get_settings()
    
    conn = await asyncpg.connect(
        str(settings.postgres_dsn),
        statement_cache_size=0,
        command_timeout=300
    )
    
    try:
        logger.info(f"Analyzing categorization for user: {user_id}")
        logger.info("=" * 80)
        
        # 1. Get all enriched transactions
        transactions = await conn.fetch("""
            SELECT 
                e.parsed_id,
                f.txn_id,
                f.merchant_name_norm,
                f.description,
                tp.counterparty_name,
                tp.channel_type,
                tp.direction AS parsed_direction,
                e.category_id,
                e.subcategory_id,
                e.confidence,
                e.cat_l1
            FROM spendsense.txn_fact f
            JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
            JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
            WHERE f.user_id = $1
            ORDER BY f.txn_date DESC
            LIMIT 500
        """, user_id)
        
        logger.info(f"Analyzing {len(transactions)} transactions...")
        
        # 2. Analyze issues
        issues = {
            'personal_names_as_shopping': [],
            'low_confidence': [],
            'missing_merchant_master': [],
            'wrong_category_patterns': defaultdict(list),
            'upi_not_transfers': [],
        }
        
        category_counts = Counter()
        method_counts = Counter()
        
        for row in transactions:
            parsed_id = row['parsed_id']
            merchant_norm = row['merchant_name_norm'] or ''
            counterparty = row['counterparty_name'] or ''
            description = row['description'] or ''
            channel = row['channel_type'] or ''
            category = row['category_id'] or ''
            subcategory = row['subcategory_id'] or ''
            confidence = float(row['confidence'] or 0)
            
            merchant_for_check = merchant_norm or counterparty or description
            merchant_normalized = merchant_for_check.lower().strip() if merchant_for_check else ''
            
            category_counts[category] += 1
            
            # Check if personal name is categorized as shopping
            if category == 'shopping' and merchant_normalized:
                is_personal = _looks_like_personal_name(merchant_normalized)
                if is_personal:
                    issues['personal_names_as_shopping'].append({
                        'parsed_id': parsed_id,
                        'merchant': merchant_normalized[:50],
                        'description': description[:60],
                        'channel': channel,
                    })
            
            # Check for low confidence
            if confidence < 0.7:
                issues['low_confidence'].append({
                    'parsed_id': parsed_id,
                    'merchant': merchant_normalized[:50],
                    'category': category,
                    'confidence': confidence,
                })
            
            # Check if merchant should be in merchant master
            if merchant_normalized and category != 'transfers_out' and category != 'transfers_in':
                cat_from_master, _ = await lookup_merchant_category(conn, merchant_normalized)
                if not cat_from_master:
                    # Not in merchant master - might be missing
                    if len(merchant_normalized.split()) <= 3:  # Short names might be merchants
                        issues['missing_merchant_master'].append({
                            'parsed_id': parsed_id,
                            'merchant': merchant_normalized[:50],
                            'category': category,
                        })
            
            # Check UPI transactions not categorized as transfers
            if channel == 'UPI' and category not in ['transfers_out', 'transfers_in']:
                is_personal = _looks_like_personal_name(merchant_normalized)
                if is_personal:
                    issues['upi_not_transfers'].append({
                        'parsed_id': parsed_id,
                        'merchant': merchant_normalized[:50],
                        'category': category,
                    })
        
        # 3. Print analysis
        logger.info("\n" + "=" * 80)
        logger.info("CATEGORIZATION ANALYSIS RESULTS")
        logger.info("=" * 80)
        
        logger.info(f"\n📊 Category Distribution:")
        for cat, count in category_counts.most_common(10):
            logger.info(f"  {cat}: {count}")
        
        logger.info(f"\n⚠️  Issues Found:")
        logger.info(f"  • Personal names categorized as shopping: {len(issues['personal_names_as_shopping'])}")
        logger.info(f"  • Low confidence transactions (<0.7): {len(issues['low_confidence'])}")
        logger.info(f"  • Missing from merchant master: {len(issues['missing_merchant_master'])}")
        logger.info(f"  • UPI personal names not transfers: {len(issues['upi_not_transfers'])}")
        
        # Show examples
        if issues['personal_names_as_shopping']:
            logger.info(f"\n🔴 Personal Names Categorized as Shopping (first 10):")
            for issue in issues['personal_names_as_shopping'][:10]:
                logger.info(f"  • {issue['merchant']} → shopping (should be transfers)")
        
        if issues['upi_not_transfers']:
            logger.info(f"\n🔴 UPI Personal Names Not Transfers (first 10):")
            for issue in issues['upi_not_transfers'][:10]:
                logger.info(f"  • {issue['merchant']} → {issue['category']} (should be transfers)")
        
        if issues['missing_merchant_master']:
            logger.info(f"\n🟡 Potential Missing Merchants (first 10):")
            for issue in issues['missing_merchant_master'][:10]:
                logger.info(f"  • {issue['merchant']} → {issue['category']}")
        
        if issues['low_confidence']:
            logger.info(f"\n🟡 Low Confidence Transactions (first 10):")
            for issue in issues['low_confidence'][:10]:
                logger.info(f"  • {issue['merchant']} → {issue['category']} (conf: {issue['confidence']:.2f})")
        
        logger.info("\n" + "=" * 80)
        logger.info("Analysis complete!")
        logger.info("=" * 80)
        
    except Exception as e:
        logger.error(f"Error analyzing categorization: {e}", exc_info=True)
    finally:
        await conn.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 -m app.spendsense.scripts.analyze_categorization <user_id>")
        sys.exit(1)
    
    user_id = sys.argv[1]
    asyncio.run(analyze_categorization(user_id))

