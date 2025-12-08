#!/usr/bin/env python3
"""
Backfill parsing and enrichment for existing transactions

This script:
1. Parses all unparsed transactions in txn_fact → txn_parsed
2. Enriches all unenriched transactions in txn_parsed → txn_enriched

This fixes the issue where transactions were ingested but not parsed/enriched
due to deduplication or other issues.

Usage:
    python -m app.spendsense.scripts.backfill_parse_and_enrich [--user-id USER_ID] [--batch-size 1000] [--dry-run]
"""
import asyncio
import logging
import sys
from pathlib import Path

# Add backend to path
backend_dir = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(backend_dir))

from app.core.config import get_settings
from app.spendsense.services.txn_parsed_populator import populate_txn_parsed_from_fact
from app.spendsense.etl.pipeline import enrich_transactions
import asyncpg

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def backfill_all_users(batch_size: int = 1000, dry_run: bool = False):
    """
    Backfill parsing and enrichment for all users
    
    Args:
        batch_size: Number of transactions to process per batch
        dry_run: If True, only count transactions without inserting
    """
    settings = get_settings()
    conn = await asyncpg.connect(str(settings.postgres_dsn), statement_cache_size=0)
    
    try:
        # Step 1: Count unparsed transactions
        unparsed_count = await conn.fetchval("""
            SELECT COUNT(*) 
            FROM spendsense.txn_fact tf
            WHERE NOT EXISTS (
                SELECT 1 FROM spendsense.txn_parsed tp 
                WHERE tp.fact_txn_id = tf.txn_id
            )
        """)
        
        logger.info(f"Found {unparsed_count} unparsed transactions")
        
        # Step 2: Count unenriched transactions (before parsing)
        unenriched_count_before = await conn.fetchval("""
            SELECT COUNT(*) 
            FROM spendsense.txn_parsed tp
            WHERE NOT EXISTS (
                SELECT 1 FROM spendsense.txn_enriched te
                WHERE te.parsed_id = tp.parsed_id
            )
        """)
        
        logger.info(f"Found {unenriched_count_before} unenriched transactions (before parsing)")
        
        if dry_run:
            logger.info("="*60)
            logger.info("DRY RUN - No changes will be made")
            logger.info("="*60)
            logger.info(f"Would parse: {unparsed_count} transactions")
            logger.info(f"Would enrich: {unenriched_count_before} transactions (may increase after parsing)")
            if unparsed_count > 0 or unenriched_count_before > 0:
                logger.info("\n⚠️  Run without --dry-run to apply changes")
            return
        
        if unparsed_count == 0 and unenriched_count_before == 0:
            logger.info("✅ All transactions are already parsed and enriched!")
            return
        
        # Step 3: Parse unparsed transactions
        if unparsed_count > 0:
            logger.info("="*60)
            logger.info("STEP 1: PARSING TRANSACTIONS")
            logger.info("="*60)
            
            parsed_total = 0
            while True:
                count = await populate_txn_parsed_from_fact(conn, batch_id=None)
                if count == 0:
                    break
                parsed_total += count
                logger.info(f"Parsed {parsed_total}/{unparsed_count} transactions")
            
            logger.info(f"✅ Parsing complete! Parsed {parsed_total} transactions")
        else:
            logger.info("✅ All transactions are already parsed")
        
        # Step 4: Re-check unenriched count AFTER parsing (newly parsed transactions need enrichment)
        unenriched_count_after = await conn.fetchval("""
            SELECT COUNT(*) 
            FROM spendsense.txn_parsed tp
            WHERE NOT EXISTS (
                SELECT 1 FROM spendsense.txn_enriched te
                WHERE te.parsed_id = tp.parsed_id
            )
        """)
        logger.info(f"Found {unenriched_count_after} unenriched transactions (after parsing)")
        
        # Step 5: Enrich unenriched transactions (per user)
        if unenriched_count_after > 0:
            logger.info("="*60)
            logger.info("STEP 2: ENRICHING TRANSACTIONS")
            logger.info("="*60)
            
            # Get all users with unenriched transactions
            users = await conn.fetch("""
                SELECT DISTINCT f.user_id
                FROM spendsense.txn_fact f
                JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
                WHERE NOT EXISTS (
                    SELECT 1 FROM spendsense.txn_enriched te
                    WHERE te.parsed_id = tp.parsed_id
                )
            """)
            
            enriched_total = 0
            for user_row in users:
                user_id = user_row['user_id']
                logger.info(f"Enriching transactions for user {user_id}...")
                
                try:
                    count = await enrich_transactions(conn, user_id, upload_id=None)
                    enriched_total += count
                    logger.info(f"  ✅ Enriched {count} transactions for user {user_id}")
                except Exception as e:
                    logger.error(f"  ❌ Failed to enrich transactions for user {user_id}: {e}", exc_info=True)
                    # Continue with other users
            
            logger.info(f"✅ Enrichment complete! Enriched {enriched_total} transactions")
        else:
            logger.info("✅ All transactions are already enriched")
        
        # Step 6: Show summary
        logger.info("="*60)
        logger.info("FINAL SUMMARY")
        logger.info("="*60)
        
        final_stats = await conn.fetch("""
            SELECT 
                COUNT(DISTINCT tf.txn_id) as total_fact,
                COUNT(DISTINCT tp.parsed_id) as total_parsed,
                COUNT(DISTINCT te.parsed_id) as total_enriched,
                COUNT(DISTINCT CASE WHEN te.category_id IS NOT NULL THEN te.parsed_id END) as with_category,
                COUNT(DISTINCT CASE WHEN te.subcategory_id IS NOT NULL THEN te.parsed_id END) as with_subcategory
            FROM spendsense.txn_fact tf
            LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
            LEFT JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
        """)
        
        stats = final_stats[0]
        logger.info(f"Total transactions (txn_fact): {stats['total_fact']}")
        logger.info(f"Parsed transactions (txn_parsed): {stats['total_parsed']}")
        logger.info(f"Enriched transactions (txn_enriched): {stats['total_enriched']}")
        logger.info(f"  - With category: {stats['with_category']}")
        logger.info(f"  - With subcategory: {stats['with_subcategory']}")
        
        if stats['total_fact'] > 0:
            parse_rate = (stats['total_parsed'] / stats['total_fact']) * 100
            enrich_rate = (stats['total_enriched'] / stats['total_parsed']) * 100 if stats['total_parsed'] > 0 else 0
            logger.info(f"Parse rate: {parse_rate:.1f}%")
            logger.info(f"Enrichment rate: {enrich_rate:.1f}%")
        
        logger.info("="*60)
        logger.info("✅ Backfill complete!")
        
    except KeyboardInterrupt:
        logger.info("\n⚠️  Interrupted by user")
        raise
    except Exception as e:
        logger.error(f"❌ Error during backfill: {e}", exc_info=True)
        raise
    finally:
        try:
            await conn.close()
        except Exception:
            pass  # Ignore errors during cleanup


async def backfill_user(user_id: str, dry_run: bool = False):
    """
    Backfill parsing and enrichment for a specific user
    
    Args:
        user_id: User ID to backfill
        dry_run: If True, only count transactions without inserting
    """
    settings = get_settings()
    conn = await asyncpg.connect(str(settings.postgres_dsn), statement_cache_size=0)
    
    try:
        # Count unparsed transactions for this user
        unparsed_count = await conn.fetchval("""
            SELECT COUNT(*) 
            FROM spendsense.txn_fact tf
            WHERE tf.user_id = $1
                AND NOT EXISTS (
                    SELECT 1 FROM spendsense.txn_parsed tp 
                    WHERE tp.fact_txn_id = tf.txn_id
                )
        """, user_id)
        
        logger.info(f"User {user_id}: Found {unparsed_count} unparsed transactions")
        
        # Count unenriched transactions for this user
        unenriched_count = await conn.fetchval("""
            SELECT COUNT(*) 
            FROM spendsense.txn_parsed tp
            JOIN spendsense.txn_fact tf ON tp.fact_txn_id = tf.txn_id
            WHERE tf.user_id = $1
                AND NOT EXISTS (
                    SELECT 1 FROM spendsense.txn_enriched te
                    WHERE te.parsed_id = tp.parsed_id
                )
        """, user_id)
        
        logger.info(f"User {user_id}: Found {unenriched_count} unenriched transactions")
        
        if dry_run:
            logger.info("DRY RUN - No changes will be made")
            return
        
        if unparsed_count == 0 and unenriched_count == 0:
            logger.info(f"✅ User {user_id}: All transactions are already parsed and enriched!")
            return
        
        # Parse unparsed transactions
        if unparsed_count > 0:
            logger.info(f"Parsing transactions for user {user_id}...")
            # Note: populate_txn_parsed_from_fact doesn't filter by user_id when batch_id=None
            # So we need to process in batches manually
            parsed_count = 0
            while True:
                # Get a batch of unparsed transactions for this user
                rows = await conn.fetch("""
                    SELECT tf.txn_id, tf.bank_code, tf.txn_date, tf.amount, tf.direction, tf.description
                    FROM spendsense.txn_fact tf
                    WHERE tf.user_id = $1
                        AND NOT EXISTS (
                            SELECT 1 FROM spendsense.txn_parsed tp 
                            WHERE tp.fact_txn_id = tf.txn_id
                        )
                    LIMIT 1000
                """, user_id)
                
                if not rows:
                    break
                
                # Parse this batch
                from app.spendsense.services.txn_parsed_populator import parse_transaction_metadata
                parsed_records = []
                for row in rows:
                    try:
                        parsed = parse_transaction_metadata(dict(row))
                        parsed_records.append(parsed)
                    except Exception as e:
                        logger.error(f"Failed to parse txn {row['txn_id']}: {e}")
                        continue
                
                if parsed_records:
                    # Bulk insert
                    await conn.executemany("""
                        INSERT INTO spendsense.txn_parsed (
                            fact_txn_id, bank_code, txn_date, amount, cr_dr,
                            channel_type, direction, raw_description,
                            counterparty_name, counterparty_bank_code, counterparty_vpa, counterparty_account,
                            upi_rrn, imps_rrn, neft_utr, mcc
                        ) VALUES (
                            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16
                        )
                        ON CONFLICT (fact_txn_id) DO UPDATE SET
                            bank_code = EXCLUDED.bank_code,
                            txn_date = EXCLUDED.txn_date,
                            amount = EXCLUDED.amount,
                            cr_dr = EXCLUDED.cr_dr,
                            channel_type = EXCLUDED.channel_type,
                            direction = EXCLUDED.direction,
                            raw_description = EXCLUDED.raw_description,
                            counterparty_name = EXCLUDED.counterparty_name,
                            counterparty_bank_code = EXCLUDED.counterparty_bank_code,
                            counterparty_vpa = EXCLUDED.counterparty_vpa,
                            counterparty_account = EXCLUDED.counterparty_account,
                            upi_rrn = EXCLUDED.upi_rrn,
                            imps_rrn = EXCLUDED.imps_rrn,
                            neft_utr = EXCLUDED.neft_utr,
                            mcc = EXCLUDED.mcc
                    """, [
                        (
                            p['fact_txn_id'], p['bank_code'], p['txn_date'], p['amount'], p['cr_dr'],
                            p['channel_type'], p['direction'], p['raw_description'],
                            p['counterparty_name'], p['counterparty_bank_code'], p['counterparty_vpa'], p['counterparty_account'],
                            p['upi_rrn'], p['imps_rrn'], p['neft_utr'], p['mcc']
                        )
                        for p in parsed_records
                    ])
                    parsed_count += len(parsed_records)
                    logger.info(f"  Parsed {parsed_count}/{unparsed_count} transactions")
            
            logger.info(f"✅ Parsed {parsed_count} transactions for user {user_id}")
        
        # Enrich unenriched transactions
        if unenriched_count > 0:
            logger.info(f"Enriching transactions for user {user_id}...")
            enriched_count = await enrich_transactions(conn, user_id, upload_id=None)
            logger.info(f"✅ Enriched {enriched_count} transactions for user {user_id}")
        
        logger.info(f"✅ Backfill complete for user {user_id}!")
        
    finally:
        await conn.close()


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Backfill parsing and enrichment for existing transactions")
    parser.add_argument("--user-id", type=str, help="Backfill for specific user only")
    parser.add_argument("--batch-size", type=int, default=1000, help="Batch size for processing")
    parser.add_argument("--dry-run", action="store_true", help="Count transactions without inserting")
    
    args = parser.parse_args()
    
    if args.user_id:
        asyncio.run(backfill_user(args.user_id, args.dry_run))
    else:
        asyncio.run(backfill_all_users(args.batch_size, args.dry_run))

