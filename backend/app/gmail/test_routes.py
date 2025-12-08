"""Test routes for Gmail parsing and auto-categorization."""

from __future__ import annotations

import asyncio
import base64
import logging
from pathlib import Path

import asyncpg
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import JSONResponse

from app.auth.dependencies import get_current_user
from app.auth.models import AuthenticatedUser
from app.core.config import get_settings
from app.dependencies.database import get_db_pool
from app.spendsense.etl.parsers import parse_email_payload
from app.spendsense.etl.pipeline import enrich_transactions

settings = get_settings()
logger = logging.getLogger(__name__)
router = APIRouter(prefix="/gmail/test", tags=["gmail-test"])


async def _persist_and_enrich(
    pool: asyncpg.Pool,
    user_id: str,
    records: list[dict],
) -> dict:
    """Persist records and enrich them, returning results."""
    conn = await pool.acquire()
    try:
        # Create upload batch
        batch_id = await conn.fetchval(
            """
            INSERT INTO spendsense.upload_batch (user_id, source_type, file_name, status)
            VALUES ($1, 'email', 'test-email', 'received')
            RETURNING upload_id
            """,
            user_id,
        )
        await conn.execute(
            "UPDATE spendsense.upload_batch SET total_records=$2 WHERE upload_id=$1",
            batch_id,
            len(records),
        )

        # Insert to staging
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
            await conn.executemany(
                """
                INSERT INTO spendsense.txn_staging (
                    upload_id, user_id, raw_txn_id, txn_date, description_raw,
                    amount, direction, currency, merchant_raw, account_ref,
                    bank_code, channel
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

        # Staging → fact transformation
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

        await conn.execute(
            "UPDATE spendsense.upload_batch SET status='loaded' WHERE upload_id=$1",
            batch_id,
        )

        # Enrich transactions
        enriched_count = await enrich_transactions(conn, user_id, str(batch_id))

        # Fetch enriched results
        results = await conn.fetch(
            """
            SELECT 
                tf.txn_id,
                tf.txn_date,
                tf.description,
                tf.amount,
                tf.direction,
                tf.merchant_name_norm,
                te.category_id AS category_code,
                te.subcategory_id AS subcategory_code,
                te.cat_l1 AS txn_type,
                te.rule_id AS matched_rule_id,
                dc.category_name,
                ds.subcategory_name
            FROM spendsense.txn_fact tf
            JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
            JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
            LEFT JOIN spendsense.dim_category dc ON dc.category_code = te.category_id
            LEFT JOIN spendsense.dim_subcategory ds ON ds.subcategory_code = te.subcategory_id 
                AND ds.category_code = te.category_id
            WHERE tf.upload_id = $1
            ORDER BY tf.txn_date DESC
            """,
            batch_id,
        )

        return {
            "batch_id": str(batch_id),
            "parsed_count": len(records),
            "enriched_count": enriched_count,
            "transactions": [
                {
                    "txn_id": str(row["txn_id"]),
                    "date": row["txn_date"].isoformat() if row["txn_date"] else None,
                    "description": row["description"],
                    "amount": float(row["amount"]),
                    "direction": row["direction"],
                    "merchant": row["merchant_name_norm"],
                    "category": {
                        "code": row["category_code"],
                        "name": row["category_name"],
                    },
                    "subcategory": {
                        "code": row["subcategory_code"],
                        "name": row["subcategory_name"],
                    },
                    "type": row["txn_type"],
                    "matched_rule_id": str(row["matched_rule_id"]) if row["matched_rule_id"] else None,
                }
                for row in results
            ],
        }
    finally:
        await pool.release(conn)


@router.post("/parse-email")
async def test_parse_email(
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
    pool=Depends(get_db_pool),
) -> JSONResponse:
    """Test endpoint: Parse an email file (.eml) and show auto-categorization results.
    
    Upload a .eml file to test:
    1. Email parsing (extracts transactions)
    2. Auto-categorization (merchant rules)
    3. Sub-categorization
    """
    if not file.filename.endswith((".eml", ".msg")):
        raise HTTPException(status_code=400, detail="File must be .eml or .msg format")
    
    try:
        # Read email file
        email_data = await file.read()
        
        # Parse email
        records = parse_email_payload(email_data, file.filename)
        
        if not records:
            return JSONResponse({
                "error": "No transactions found in email",
                "parsed_count": 0,
            })
        
        # Persist and enrich
        result = await _persist_and_enrich(pool, user.user_id, records)
        
        return JSONResponse({
            "success": True,
            **result,
        })
        
    except Exception as exc:
        logger.exception("Failed to parse test email")
        raise HTTPException(status_code=500, detail=f"Failed to parse email: {str(exc)}")


@router.post("/parse-sample")
async def test_parse_sample_email(
    user: AuthenticatedUser = Depends(get_current_user),
    pool=Depends(get_db_pool),
) -> JSONResponse:
    """Test endpoint: Parse a sample HDFC email alert and show categorization.
    
    Uses a hardcoded sample email for testing.
    """
    # Sample HDFC debit alert email (proper email format)
    sample_email = b"""From: alerts@hdfcbank.com
To: user@example.com
Subject: Transaction Alert - Debit
Content-Type: text/plain

Dear Customer,

Your HDFC Bank Account ending 1234 has been debited with INR 500.00 on 18-Nov-2024 at 14:30.

Transaction Details:
Amount: INR 500.00
Merchant: ZOMATO LIMITED
UPI Ref: UPI-ZOMATO LIMITED-ZOMATO4.PAYU@ICICI-1234567890
Date: 18-Nov-2024

Thank you for banking with HDFC Bank.
"""
    
    try:
        # Parse email
        records = parse_email_payload(sample_email, "sample-hdfc.eml")
        
        if not records:
            return JSONResponse({
                "error": "No transactions found in sample email",
                "parsed_count": 0,
            })
        
        # Persist and enrich
        result = await _persist_and_enrich(pool, user.user_id, records)
        
        return JSONResponse({
            "success": True,
            "sample_email": "HDFC debit alert",
            **result,
        })
        
    except Exception as exc:
        logger.exception("Failed to parse sample email")
        raise HTTPException(status_code=500, detail=f"Failed to parse sample email: {str(exc)}")


@router.get("/view-rules")
async def view_merchant_rules(
    user: AuthenticatedUser = Depends(get_current_user),
    pool=Depends(get_db_pool),
) -> JSONResponse:
    """View active merchant rules for debugging categorization."""
    conn = await pool.acquire()
    try:
        rules = await conn.fetch(
            """
            SELECT 
                rule_id,
                pattern_regex,
                applies_to,
                category_code,
                subcategory_code,
                priority,
                active
            FROM spendsense.merchant_rules
            WHERE active = TRUE
            ORDER BY priority ASC, applies_to
            """
        )
        
        return JSONResponse({
            "rules": [
                {
                    "rule_id": str(row["rule_id"]),
                    "pattern": row["pattern_regex"],
                    "applies_to": row["applies_to"],
                    "category": row["category_code"],
                    "subcategory": row["subcategory_code"],
                    "priority": row["priority"],
                }
                for row in rules
            ],
            "count": len(rules),
        })
    finally:
        await pool.release(conn)

