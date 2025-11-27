import asyncio
import base64
import json
import logging

import asyncpg

from app.celery_app import celery_app
from app.core.config import get_settings
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
    try:
        # Parse file first (before DB connection) to fail fast on parse errors
        logger.info(f"Parsing file: {filename}")
        records = parse_transactions_file(file_bytes, filename, pdf_password)
        logger.info(f"Parsed {len(records)} records from {filename}")
        
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
                    LOWER(COALESCE(TRIM(s.merchant_raw), '')) AS m_norm,
                    md5(LOWER(COALESCE(TRIM(s.merchant_raw), ''))) AS m_hash
                FROM s
            ),
            alias_match AS (
                SELECT
                    n.*,
                    ma_user.normalized_name AS user_alias_name,
                    ma_user.channel_override AS user_alias_channel,
                    ma_global.normalized_name AS global_alias_name,
                    ma_global.channel_override AS global_alias_channel
                FROM norm n
                LEFT JOIN spendsense.merchant_alias ma_user
                    ON ma_user.user_id = n.user_id AND ma_user.merchant_hash = n.m_hash
                LEFT JOIN spendsense.merchant_alias ma_global
                    ON ma_global.user_id IS NULL AND ma_global.merchant_hash = n.m_hash
            ),
            m_match AS (
                SELECT
                    a.*,
                    dm.merchant_id,
                    COALESCE(
                        a.user_alias_name,
                        a.global_alias_name,
                        dm.normalized_name,
                        CASE 
                            WHEN NULLIF(a.m_norm, '') IS NOT NULL 
                            THEN INITCAP(REGEXP_REPLACE(a.m_norm, '\s+', ' ', 'g'))
                            ELSE NULL
                        END
                    ) AS normalized_name,
                    COALESCE(
                        a.user_alias_channel,
                        a.global_alias_channel,
                        a.channel
                    ) AS resolved_channel
                FROM alias_match a
                LEFT JOIN spendsense.dim_merchant dm
                    ON dm.normalized_name = COALESCE(
                        a.user_alias_name,
                        a.global_alias_name,
                        CASE 
                            WHEN NULLIF(a.m_norm, '') IS NOT NULL 
                            THEN INITCAP(REGEXP_REPLACE(a.m_norm, '\s+', ' ', 'g'))
                            ELSE NULL
                        END
                    )
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
        logger.info(f"Staging → fact transformation complete for batch {batch_id}")

        # Populate txn_parsed table with parsed transaction metadata
        logger.info(f"Populating txn_parsed table for batch {batch_id}")
        try:
            await conn.execute("SELECT spendsense.populate_txn_parsed()")
            parsed_count = await conn.fetchval(
                """
                SELECT COUNT(*) 
                FROM spendsense.txn_parsed tp
                INNER JOIN spendsense.txn_fact tf ON tf.txn_id = tp.fact_txn_id
                WHERE tf.upload_id = $1
                """,
                batch_id,
            )
            logger.info(f"Populated {parsed_count} records in txn_parsed for batch {batch_id}")
        except Exception as exc:
            logger.warning(f"Failed to populate txn_parsed for batch {batch_id}: {exc}")

        # Enrich transactions with categories and subcategories
        logger.info(f"Enriching transactions with categories for batch {batch_id}")
        enriched_count = await enrich_transactions(conn, user_id, batch_id)
        logger.info(f"Enriched {enriched_count} transactions for batch {batch_id}")

        logger.info(f"Marking batch {batch_id} as loaded")
        await conn.execute(
            "UPDATE spendsense.upload_batch SET status='loaded' WHERE upload_id=$1",
            batch_id,
        )
        logger.info(f"Ingestion complete for batch {batch_id}")
    except SpendSenseParseError as exc:
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

