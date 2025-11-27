from __future__ import annotations

import logging
from typing import Sequence

import asyncpg

from app.services.realtime import broadcast_transaction_created
from app.spendsense.etl.pipeline import enrich_transactions

logger = logging.getLogger(__name__)


async def persist_records_async(
    conn: asyncpg.Connection,
    user_id: str,
    records: Sequence[dict],
    *,
    source_label: str,
    broadcast: bool = False,
) -> None:
    """Persist parsed transaction records via staging -> fact pipeline."""
    if not records:
        return

    batch_id = await conn.fetchval(
        """
        INSERT INTO spendsense.upload_batch (user_id, source_type, file_name, status)
        VALUES ($1, 'email', $2, 'received')
        RETURNING upload_id
        """,
        user_id,
        source_label,
    )

    await conn.execute(
        "UPDATE spendsense.upload_batch SET total_records=$2 WHERE upload_id=$1",
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
            rec.get("currency", "INR"),
            rec.get("merchant_raw"),
            rec.get("account_ref"),
            rec.get("bank_code"),
            rec.get("channel"),
        )
        for rec in records
    ]

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

    await conn.execute(
        """
        UPDATE spendsense.upload_batch SET status='parsed', parsed_records=$2 WHERE upload_id=$1
        """,
        batch_id,
        len(records),
    )

    await conn.execute(
        """
        WITH s AS (
            SELECT * FROM spendsense.txn_staging WHERE upload_id = $1
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
            'email',
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

    # Populate txn_parsed table with parsed transaction metadata
    try:
        await conn.execute("SELECT spendsense.populate_txn_parsed()")
    except Exception as exc:
        logger.warning(f"Failed to populate txn_parsed for batch {batch_id}: {exc}")

    await conn.execute(
        "UPDATE spendsense.upload_batch SET status='loaded' WHERE upload_id=$1",
        batch_id,
    )

    await enrich_transactions(conn, user_id, str(batch_id))

    if broadcast:
        rows = await conn.fetch(
            """
            SELECT
                txn_id,
                txn_date,
                description,
                amount,
                direction,
                currency,
                merchant_name_norm,
                channel
            FROM spendsense.txn_fact
            WHERE upload_id = $1
            """,
            batch_id,
        )
        for row in rows:
            broadcast_transaction_created(
                user_id,
                {
                    "id": str(row["txn_id"]),
                    "txn_date": row["txn_date"].isoformat(),
                    "amount": float(row["amount"]),
                    "direction": row["direction"],
                    "currency": row["currency"],
                    "merchant_raw": row["merchant_name_norm"],
                    "description_raw": row["description"],
                    "channel": row["channel"],
                },
            )


