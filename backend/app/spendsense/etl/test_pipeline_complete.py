"""
Complete pipeline test - verifies end-to-end flow

Run with: python -m app.spendsense.etl.test_pipeline_complete
"""

import asyncio
import logging
from pathlib import Path
from datetime import date

import asyncpg
from dotenv import load_dotenv

# Add parent directory to path
import sys
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from app.spendsense.services.txn_parsed_populator import populate_txn_parsed_from_fact
from app.spendsense.etl.pipeline import enrich_transactions

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


async def test_pipeline_flow():
    """Test the complete pipeline flow."""
    load_dotenv()
    
    import os
    postgres_url = os.getenv("POSTGRES_URL", "")
    if not postgres_url:
        logger.error("POSTGRES_URL not found in environment")
        return False
    
    # Disable prepared statements for pgbouncer compatibility
    conn = await asyncpg.connect(postgres_url, statement_cache_size=0)
    
    try:
        logger.info("=" * 80)
        logger.info("TESTING COMPLETE PIPELINE FLOW")
        logger.info("=" * 80)
        
        # Test 1: Check if we can query txn_fact by upload_id
        logger.info("\n[TEST 1] Checking txn_fact structure...")
        test_upload_id = await conn.fetchval("""
            SELECT upload_id FROM spendsense.txn_fact 
            ORDER BY created_at DESC 
            LIMIT 1
        """)
        if test_upload_id:
            fact_count = await conn.fetchval("""
                SELECT COUNT(*) FROM spendsense.txn_fact WHERE upload_id = $1
            """, test_upload_id)
            logger.info(f"✅ Found test batch: {test_upload_id} with {fact_count} transactions")
        else:
            logger.warning("⚠️  No transactions in txn_fact to test with")
        
        # Test 2: Check parsing query
        logger.info("\n[TEST 2] Testing parsing query...")
        if test_upload_id:
            unparsed_count = await conn.fetchval("""
                SELECT COUNT(*) 
                FROM spendsense.txn_fact tf
                WHERE tf.upload_id = $1
                    AND NOT EXISTS (
                        SELECT 1 FROM spendsense.txn_parsed tp
                        WHERE tp.fact_txn_id = tf.txn_id
                    )
            """, test_upload_id)
            logger.info(f"✅ Found {unparsed_count} unparsed transactions for batch {test_upload_id}")
            
            # Try parsing
            if unparsed_count > 0:
                logger.info(f"  → Running populate_txn_parsed_from_fact for batch {test_upload_id}...")
                parsed_count = await populate_txn_parsed_from_fact(conn, test_upload_id)
                logger.info(f"  ✅ Parsed {parsed_count} transactions")
        
        # Test 3: Check enrichment query
        logger.info("\n[TEST 3] Testing enrichment query...")
        if test_upload_id:
            # Get a user_id from the batch
            user_id = await conn.fetchval("""
                SELECT user_id FROM spendsense.txn_fact 
                WHERE upload_id = $1 
                LIMIT 1
            """, test_upload_id)
            
            if user_id:
                unenriched_count = await conn.fetchval("""
                    SELECT COUNT(DISTINCT tp.parsed_id)
                    FROM spendsense.txn_fact tf
                    JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
                    WHERE tf.upload_id = $1
                        AND NOT EXISTS (
                            SELECT 1 FROM spendsense.txn_enriched te
                            WHERE te.parsed_id = tp.parsed_id
                        )
                """, test_upload_id)
                logger.info(f"✅ Found {unenriched_count} unenriched transactions for batch {test_upload_id}")
                
                # Try enriching
                if unenriched_count > 0:
                    logger.info(f"  → Running enrich_transactions for user {user_id}, batch {test_upload_id}...")
                    enriched_count = await enrich_transactions(conn, user_id, test_upload_id)
                    logger.info(f"  ✅ Enriched {enriched_count} transactions")
        
        # Test 4: Verify data flow
        logger.info("\n[TEST 4] Verifying complete data flow...")
        if test_upload_id:
            staging_count = await conn.fetchval("""
                SELECT COUNT(*) FROM spendsense.txn_staging WHERE upload_id = $1
            """, test_upload_id)
            fact_count = await conn.fetchval("""
                SELECT COUNT(*) FROM spendsense.txn_fact WHERE upload_id = $1
            """, test_upload_id)
            parsed_count = await conn.fetchval("""
                SELECT COUNT(DISTINCT tp.parsed_id)
                FROM spendsense.txn_fact tf
                JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
                WHERE tf.upload_id = $1
            """, test_upload_id)
            enriched_count = await conn.fetchval("""
                SELECT COUNT(DISTINCT te.enriched_id)
                FROM spendsense.txn_fact tf
                JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
                JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
                WHERE tf.upload_id = $1
            """, test_upload_id)
            
            logger.info(f"  Staging:     {staging_count}")
            logger.info(f"  Fact:        {fact_count}")
            logger.info(f"  Parsed:      {parsed_count}")
            logger.info(f"  Enriched:    {enriched_count}")
            
            if fact_count > 0:
                parse_pct = (parsed_count / fact_count) * 100 if fact_count > 0 else 0
                enrich_pct = (enriched_count / parsed_count) * 100 if parsed_count > 0 else 0
                logger.info(f"  Parse rate:  {parse_pct:.1f}%")
                logger.info(f"  Enrich rate: {enrich_pct:.1f}%")
                
                if parse_pct < 100:
                    logger.warning(f"  ⚠️  Only {parse_pct:.1f}% of transactions are parsed!")
                if parsed_count > 0 and enrich_pct < 100:
                    logger.warning(f"  ⚠️  Only {enrich_pct:.1f}% of parsed transactions are enriched!")
        
        # Test 5: Check for common issues
        logger.info("\n[TEST 5] Checking for common issues...")
        
        # Check for transactions with missing categories
        missing_categories = await conn.fetchval("""
            SELECT COUNT(*)
            FROM spendsense.txn_enriched te
            WHERE te.category_id IS NULL OR te.subcategory_id IS NULL
        """)
        if missing_categories > 0:
            logger.warning(f"  ⚠️  Found {missing_categories} enriched transactions with missing categories")
        else:
            logger.info("  ✅ All enriched transactions have categories")
        
        # Check for invalid category codes
        invalid_categories = await conn.fetchval("""
            SELECT COUNT(*)
            FROM spendsense.txn_enriched te
            LEFT JOIN spendsense.dim_category dc ON dc.category_code = te.category_id
            WHERE te.category_id IS NOT NULL AND dc.category_code IS NULL
        """)
        if invalid_categories > 0:
            logger.warning(f"  ⚠️  Found {invalid_categories} enriched transactions with invalid category codes")
        else:
            logger.info("  ✅ All category codes are valid")
        
        logger.info("\n" + "=" * 80)
        logger.info("✅ PIPELINE TEST COMPLETE")
        logger.info("=" * 80)
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Pipeline test failed: {e}", exc_info=True)
        return False
        
    finally:
        await conn.close()


if __name__ == "__main__":
    success = asyncio.run(test_pipeline_flow())
    sys.exit(0 if success else 1)

