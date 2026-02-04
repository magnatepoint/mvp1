import asyncio
import base64
import json
import logging

import asyncpg

from app.celery_app import celery_app
from app.core.config import get_settings
from app.spendsense.services.txn_parsed_populator import populate_txn_parsed_from_fact
from .parsers import SpendSenseParseError, parse_transactions_file
from .pipeline import enrich_transactions

settings = get_settings()
logger = logging.getLogger(__name__)


@celery_app.task(name="spendsense.ingest_statement_file")
def ingest_statement_file_task(
    batch_id: str,
    user_id: str,
    filename: str,
    file_b64: str,
    pdf_password: str | None = None,
) -> None:
    logger.info(f"Starting ingestion for batch {batch_id}, file: {filename}")
    data = base64.b64decode(file_b64)
    logger.info(f"Decoded file size: {len(data)} bytes")
    asyncio.run(_ingest(batch_id, user_id, filename, data, pdf_password))


async def _ingest(
    batch_id: str,
    user_id: str,
    filename: str,
    file_bytes: bytes,
    pdf_password: str | None = None,
) -> None:
    conn = None
    
    # Helper function to update batch status on error
    async def update_batch_error(error_msg: str) -> None:
        """Update batch status to failed with error message."""
        try:
            error_conn = await asyncio.wait_for(
                asyncpg.connect(
                    str(settings.postgres_dsn),
                    statement_cache_size=0,
                    timeout=30,
                ),
                timeout=35.0,
            )
            try:
                await error_conn.execute(
                    """
                    UPDATE spendsense.upload_batch
                    SET status='failed', error_json=$2
                    WHERE upload_id=$1
                    """,
                    batch_id,
                    json.dumps({"error": error_msg}),
                )
                logger.error(f"Updated batch {batch_id} status to 'failed': {error_msg}")
            finally:
                await error_conn.close()
        except Exception as update_exc:
            logger.error(f"Failed to update batch {batch_id} error status: {update_exc}")
    
    try:
        # Parse file first (before DB connection) to fail fast on parse errors
        logger.info(f"Parsing file: {filename}")
        try:
            records = parse_transactions_file(file_bytes, filename, pdf_password)
            logger.info(f"Parsed {len(records)} records from {filename}")
        except SpendSenseParseError as parse_exc:
            # Update batch status before re-raising
            error_msg = str(parse_exc)
            logger.error(f"Parse error for batch {batch_id}: {error_msg}")
            await update_batch_error(error_msg)
            raise
        
        # Now connect to database with retry logic
        logger.info("Connecting to database...")
        max_retries = 3
        retry_delay = 2  # seconds
        conn = None
        
        for attempt in range(max_retries):
            try:
                conn = await asyncio.wait_for(
                    asyncpg.connect(
                        str(settings.postgres_dsn),
                        statement_cache_size=0,
                        command_timeout=300,  # 5 minute timeout for long operations
                        timeout=30,  # 30 second connection timeout
                    ),
                    timeout=35.0,  # Slightly longer than connection timeout
                )
                logger.info("Database connection established")
                break
            except (asyncio.TimeoutError, OSError, Exception) as exc:
                if attempt < max_retries - 1:
                    logger.warning(
                        f"Database connection attempt {attempt + 1} failed: {exc}. Retrying in {retry_delay}s..."
                    )
                    await asyncio.sleep(retry_delay)
                    retry_delay *= 2  # Exponential backoff
                else:
                    logger.error(f"Failed to connect to database after {max_retries} attempts: {exc}")
                    raise
        
        if conn is None:
            raise RuntimeError("Failed to establish database connection")
        
        logger.info(f"Updating batch {batch_id} with {len(records)} records")
        await conn.execute(
            """
            UPDATE spendsense.upload_batch
            SET total_records=$2
            WHERE upload_id=$1
            """,
            batch_id,
            len(records),
        )

        staging_params = [
            (
                batch_id,
                user_id,
                rec.get("raw_txn_id"),
                rec["txn_date"],
                rec["description_raw"],
                rec["amount"],
                rec["direction"],
                rec["currency"],
                rec.get("merchant_raw"),
                rec.get("account_ref"),
                rec.get("bank_code"),
                rec.get("channel"),
            )
            for rec in records
        ]

        if staging_params:
            logger.info(f"Inserting {len(staging_params)} records into staging...")
            await conn.executemany(
                """
                INSERT INTO spendsense.txn_staging (
                    upload_id,
                    user_id,
                    raw_txn_id,
                    txn_date,
                    description_raw,
                    amount,
                    direction,
                    currency,
                    merchant_raw,
                    account_ref,
                    bank_code,
                    channel
                ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
                """,
                staging_params,
            )
            logger.info("Staging insert complete")

        # Transform staging → fact (normalize merchants and load into fact table)
        logger.info(f"Transforming staging → fact for batch {batch_id}")
        await conn.execute(
            """
            WITH s AS (
                SELECT *
                FROM spendsense.txn_staging
                WHERE upload_id = $1
            ),
            norm AS (
                SELECT
                    s.*,
                    -- Clean and normalize merchant name: remove transaction IDs, bank codes, UPI prefixes, etc.
                    -- Use multiple REGEXP_REPLACE calls for better control and PostgreSQL compatibility
                    LOWER(TRIM(REGEXP_REPLACE(
                        REGEXP_REPLACE(
                            REGEXP_REPLACE(
                                REGEXP_REPLACE(
                                    REGEXP_REPLACE(
                                        REGEXP_REPLACE(
                                            COALESCE(TRIM(s.merchant_raw), ''),
                                            -- Remove UPI/IMPS/NEFT/RTGS/ACH prefixes (case-insensitive)
                                            '^[Uu][Pp][Ii][-/]?|^[Ii][Mm][Pp][Ss][-/]?|^[Nn][Ee][Ff][Tt][-/]?|^[Rr][Tt][Gg][Ss][-/]?|^[Aa][Cc][Hh][-/]?', '', 'g'
                                        ),
                                        -- Remove bank codes like UTIB0000100-, CNRB0006026-, BK0007453-, etc. (case-insensitive)
                                        '^[A-Za-z]{2,4}[0-9]{6,}[-/]?', '', 'g'
                                    ),
                                    -- Remove transaction IDs (10+ digit numbers)
                                    '[0-9]{10,}', '', 'g'
                                ),
                                -- Remove common prefixes (case-insensitive, using ~* pattern matching)
                                -- This will be done in a separate step for better control
                                '^(to[[:space:]]+transfer[-/]?|payment[[:space:]]+from|request[[:space:]]+from|pay[[:space:]]+to|from[[:space:]]+phone|tfromphone)', '', 'gi'
                            ),
                            -- Remove bank code prefixes (more patterns)
                            '^(pregeneratedqr[0-9]+|bk[0-9]+[-/]?|nrb[-/]?|ici[-/]?|ib[0-9]+[-/]?|s[-/]?|pl[-/]?|is[-/]?|xis[-/]?|i[-/]?|mu[-/]?|tib[0-9]+[-/]?|ucba[0-9]+[-/]?|cnrb[0-9]+[-/]?|fdrl[0-9]+[-/]?|utib[0-9]+[-/]?|kkbk[0-9]+[-/]?)[[:space:]]*', '', 'gi'
                        ),
                        -- Collapse multiple spaces, dashes, slashes into single space
                        '[[:space:]\-/]+', ' ', 'g'
                    ))) AS m_norm,
                    md5(LOWER(COALESCE(TRIM(s.merchant_raw), ''))) AS m_hash
                FROM s
            ),
            alias_match AS (
                SELECT
                    n.*,
                    dm_from_alias.merchant_id AS alias_merchant_id,
                    dm_from_alias.normalized_name AS alias_merchant_name
                FROM norm n
                LEFT JOIN spendsense.merchant_alias ma
                    ON ma.normalized_alias = n.m_norm
                LEFT JOIN spendsense.dim_merchant dm_from_alias
                    ON dm_from_alias.merchant_id = ma.merchant_id
                    AND dm_from_alias.active = TRUE
            ),
            m_match AS (
                SELECT
                    a.*,
                    COALESCE(
                        a.alias_merchant_id,
                        dm.merchant_id
                    ) AS merchant_id,
                    -- Store normalized_name as lowercase for consistent matching with merchant_rules
                    -- Display name can be derived from dim_merchant.merchant_name or INITCAP(normalized_name)
                    COALESCE(
                        a.alias_merchant_name,
                        dm.normalized_name,
                        CASE 
                            WHEN NULLIF(a.m_norm, '') IS NOT NULL 
                            THEN LOWER(REGEXP_REPLACE(a.m_norm, '\\s+', ' ', 'g'))
                            ELSE NULL
                        END
                    ) AS normalized_name,
                    a.channel AS resolved_channel
                FROM alias_match a
                LEFT JOIN spendsense.dim_merchant dm
                    ON dm.normalized_name = COALESCE(
                        a.alias_merchant_name,
                        CASE 
                            WHEN NULLIF(a.m_norm, '') IS NOT NULL 
                            THEN LOWER(REGEXP_REPLACE(a.m_norm, '\\s+', ' ', 'g'))
                            ELSE NULL
                        END
                    )
                    AND dm.active = TRUE
            )
            INSERT INTO spendsense.txn_fact (
                user_id, upload_id, source_type, account_ref, txn_external_id, txn_date,
                description, amount, direction, currency, merchant_id, merchant_name_norm,
                bank_code, channel
            )
            SELECT DISTINCT ON (
                m.user_id, 
                m.txn_date, 
                m.amount, 
                m.direction, 
                COALESCE(m.raw_txn_id, ''), 
                COALESCE(m.normalized_name, '')
            )
                m.user_id, 
                m.upload_id, 
                (SELECT source_type FROM spendsense.upload_batch ub WHERE ub.upload_id = m.upload_id),
                m.account_ref, 
                m.raw_txn_id, 
                m.txn_date,
                m.description_raw, 
                m.amount, 
                m.direction, 
                m.currency, 
                m.merchant_id, 
                m.normalized_name,
                m.bank_code,
                m.resolved_channel
            FROM m_match m
            WHERE NOT EXISTS (
                SELECT 1 FROM spendsense.txn_fact tf
                WHERE tf.user_id = m.user_id
                    AND tf.txn_date = m.txn_date
                    AND tf.amount = m.amount
                    AND tf.direction = m.direction
                    AND COALESCE(tf.txn_external_id, '') = COALESCE(m.raw_txn_id, '')
                    AND COALESCE(tf.merchant_name_norm, '') = COALESCE(m.normalized_name, '')
            )
            ORDER BY m.user_id, m.txn_date, m.amount, m.direction, COALESCE(m.raw_txn_id, ''), COALESCE(m.normalized_name, '')
            """,
            batch_id,
        )
        
        # Log how many were actually inserted vs deduplicated
        staging_count = await conn.fetchval(
            "SELECT COUNT(*) FROM spendsense.txn_staging WHERE upload_id = $1",
            batch_id
        )
        fact_count_new = await conn.fetchval("""
            SELECT COUNT(*) 
            FROM spendsense.txn_fact 
            WHERE upload_id = $1
        """, batch_id)
        fact_count_total = await conn.fetchval("""
            SELECT COUNT(DISTINCT tf.txn_id)
            FROM spendsense.txn_staging ts
            JOIN spendsense.txn_fact tf ON (
                tf.user_id = ts.user_id
                AND tf.txn_date = ts.txn_date
                AND tf.amount = ts.amount
                AND tf.direction = ts.direction
                AND COALESCE(tf.txn_external_id, '') = COALESCE(ts.raw_txn_id, '')
            )
            WHERE ts.upload_id = $1
        """, batch_id)
        logger.info(f"Staging → fact: {staging_count} in staging, {fact_count_new} NEW inserted, {fact_count_total} TOTAL matched (including deduplicated)")
        
        logger.info(f"Staging → fact transformation complete for batch {batch_id}")

        # Populate txn_parsed table with parsed transaction metadata using Python parser
        logger.info(f"Populating txn_parsed table for batch {batch_id}")
        try:
            parsed_count = await populate_txn_parsed_from_fact(conn, batch_id)
            logger.info(f"Populated {parsed_count} records in txn_parsed for batch {batch_id}")
            if parsed_count == 0:
                logger.warning(f"No transactions were parsed for batch {batch_id}. This may indicate deduplication or parsing issues.")
        except Exception as exc:
            logger.error(f"Failed to populate txn_parsed for batch {batch_id}: {exc}", exc_info=True)
            raise  # Re-raise to fail the batch

        # Enrich transactions with categories and subcategories
        logger.info(f"Enriching transactions with categories for batch {batch_id}")
        try:
            enriched_count = await enrich_transactions(conn, user_id, batch_id)
            
            # Process enriched transactions through GoalRealtimeEngine
            if enriched_count > 0:
                try:
                    from app.goals.transaction_hook import process_transactions_for_goals
                    await process_transactions_for_goals(conn, user_id, batch_id)
                except Exception as goal_error:
                    logger.warning(
                        f"Failed to process transactions for goals (non-fatal): {goal_error}",
                        exc_info=True,
                    )
            logger.info(f"Enriched {enriched_count} transactions for batch {batch_id}")
            if enriched_count == 0:
                logger.warning(f"No transactions were enriched for batch {batch_id}. This may indicate no parsed transactions or enrichment rule issues.")
        except Exception as exc:
            logger.error(f"Failed to enrich transactions for batch {batch_id}: {exc}", exc_info=True)
            # Don't fail the batch if enrichment fails - transactions are still usable
            logger.warning(f"Continuing despite enrichment failure for batch {batch_id}")

        logger.info(f"Marking batch {batch_id} as loaded")
        await conn.execute(
            "UPDATE spendsense.upload_batch SET status='loaded' WHERE upload_id=$1",
            batch_id,
        )
        logger.info(f"Ingestion complete for batch {batch_id}")
    except SpendSenseParseError as exc:
        error_msg = str(exc)
        logger.error(f"Parse error for batch {batch_id}: {error_msg}")
        
        # Update batch status - create connection if we don't have one
        if conn is not None:
            try:
                await asyncio.wait_for(
                    conn.execute(
                        """
                        UPDATE spendsense.upload_batch
                        SET status='failed', error_json=$2
                        WHERE upload_id=$1
                        """,
                        batch_id,
                        json.dumps({"error": error_msg}),
                    ),
                    timeout=10.0,
                )
            except (asyncio.TimeoutError, Exception) as update_exc:
                logger.error(f"Failed to update batch {batch_id} status with existing connection: {update_exc}")
        else:
            # No connection yet - create one just to update status
            await update_batch_error(error_msg)
        raise
    except Exception as exc:  # pragma: no cover - safety net
        # Try to update batch status if we have a connection
        if conn is not None:
            try:
                await asyncio.wait_for(
                    conn.execute(
            """
            UPDATE spendsense.upload_batch
            SET status='failed', error_json=$2
            WHERE upload_id=$1
            """,
            batch_id,
            json.dumps({"error": str(exc)}),
                    ),
                    timeout=10.0,  # 10 second timeout for error update
        )
            except (asyncio.TimeoutError, Exception):
                pass  # Ignore errors when updating error status
        raise
    finally:
        # Ensure connection is closed with timeout
        if conn is not None:
            try:
                await asyncio.wait_for(conn.close(), timeout=5.0)
            except (asyncio.TimeoutError, Exception):
                # Force close if timeout or other error
                if not conn.is_closed():
                    conn.terminate()

