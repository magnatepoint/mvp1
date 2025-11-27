"""Celery beat task to renew Gmail watches before they expire."""

from __future__ import annotations

import logging
from datetime import datetime, timedelta

import asyncpg
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from app.celery_app import celery_app
from app.core.config import get_settings
from app.gmail.pubsub import setup_gmail_watch

settings = get_settings()
logger = logging.getLogger(__name__)


@celery_app.task(name="gmail.renew_watches")
def renew_gmail_watches_task() -> None:
    """Renew Gmail watches that are expiring soon (within 24 hours)."""
    import asyncio
    asyncio.run(_renew_watches())


async def _renew_watches() -> None:
    """Renew watches that expire within 24 hours."""
    conn: asyncpg.Connection | None = None
    try:
        conn = await asyncpg.connect(str(settings.postgres_dsn), statement_cache_size=0)
        
        # Find watches expiring within 24 hours
        expiry_threshold = datetime.utcnow() + timedelta(hours=24)
        expiring_watches = await conn.fetch(
            """
            SELECT gw.user_id, gw.history_id, gc.access_token, gc.refresh_token
            FROM spendsense.gmail_watch gw
            JOIN spendsense.gmail_connection gc ON gc.user_id = gw.user_id
            WHERE gw.expires_at <= $1
            """,
            expiry_threshold,
        )
        
        if not expiring_watches:
            logger.info("No Gmail watches need renewal")
            return
        
        logger.info("Renewing %d Gmail watches", len(expiring_watches))
        
        for watch_row in expiring_watches:
            user_id = str(watch_row["user_id"])
            try:
                # Set up new watch
                watch_info = setup_gmail_watch(
                    user_id=user_id,
                    access_token=watch_row["access_token"],
                    refresh_token=watch_row["refresh_token"],
                )
                
                # Update watch in database
                expires_at = datetime.fromisoformat(watch_info["expires_at"])
                await conn.execute(
                    """
                    UPDATE spendsense.gmail_watch
                    SET watch_id=$2, history_id=$3, expires_at=$4, updated_at=NOW()
                    WHERE user_id=$1
                    """,
                    user_id,
                    watch_info["watch_id"],
                    watch_info["history_id"],
                    expires_at,
                )
                
                logger.info("Renewed Gmail watch for user %s, expires at %s", user_id, expires_at)
                
            except Exception as exc:
                logger.exception("Failed to renew watch for user %s: %s", user_id, exc)
        
    except Exception as exc:
        logger.exception("Failed to renew Gmail watches: %s", exc)
    finally:
        if conn:
            await conn.close()

