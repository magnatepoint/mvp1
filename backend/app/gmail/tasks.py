from __future__ import annotations

import asyncio
import base64
import logging
from datetime import datetime, timedelta

import asyncpg
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from app.celery_app import celery_app
from app.core.config import get_settings
from app.gmail.persistence import persist_records_async
from app.spendsense.etl.parsers import parse_email_payload

settings = get_settings()
logger = logging.getLogger(__name__)


@celery_app.task(name="gmail.sync_inbox")
def sync_gmail_inbox_task(job_id: str) -> None:
    asyncio.run(_sync(job_id))


async def _sync(job_id: str) -> None:
    conn: asyncpg.Connection | None = None
    try:
        # Connect with retry logic
        max_retries = 3
        retry_delay = 2
        for attempt in range(max_retries):
            try:
                conn = await asyncio.wait_for(
                    asyncpg.connect(
                        str(settings.postgres_dsn),
                        statement_cache_size=0,
                        timeout=30,  # 30 second connection timeout
                    ),
                    timeout=35.0,
                )
                break
            except (asyncio.TimeoutError, OSError, Exception) as exc:
                if attempt < max_retries - 1:
                    logger.warning(f"Database connection attempt {attempt + 1} failed: {exc}. Retrying...")
                    await asyncio.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    logger.error(f"Failed to connect to database after {max_retries} attempts: {exc}")
                    raise
        
        if conn is None:
            raise RuntimeError("Failed to establish database connection")
        job_row = await conn.fetchrow(
            "SELECT job_id, user_id, status FROM spendsense.gmail_sync_job WHERE job_id=$1",
            job_id,
        )
        if not job_row:
            logger.error("Gmail job %s not found", job_id)
            return
        user_id = str(job_row["user_id"])

        await conn.execute(
            "UPDATE spendsense.gmail_sync_job SET status='authorizing', updated_at=NOW() WHERE job_id=$1",
            job_id,
        )

        connection = await conn.fetchrow(
            "SELECT access_token, refresh_token, token_expiry FROM spendsense.gmail_connection WHERE user_id=$1",
            user_id,
        )
        if not connection:
            await conn.execute(
                "UPDATE spendsense.gmail_sync_job SET status='failed', error='No Gmail connection', updated_at=NOW() WHERE job_id=$1",
                job_id,
            )
            return

        creds = Credentials(
            token=connection["access_token"],
            refresh_token=connection["refresh_token"],
            token_uri=str(settings.gmail_token_uri),
            client_id=settings.gmail_client_id,
            client_secret=settings.gmail_client_secret,
            scopes=["https://www.googleapis.com/auth/gmail.readonly"],
        )
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
            await conn.execute(
                """
                UPDATE spendsense.gmail_connection
                SET access_token=$2, token_expiry=$3, updated_at=NOW()
                WHERE user_id=$1
                """,
                user_id,
                creds.token,
                datetime.utcnow() + timedelta(seconds=3600),
            )

        service = build("gmail", "v1", credentials=creds, cache_discovery=False)
        # Search for bank alerts for the past year to capture long-tail activity
        one_year_ago = (datetime.utcnow() - timedelta(days=365)).strftime("%Y/%m/%d")
        
        queries = [
            f"after:{one_year_ago} (debited OR credited OR \"money received\" OR \"transaction alert\")",
            f"after:{one_year_ago} from:(hdfcbank.com OR sbi.co.in OR icicibank.com OR axisbank.com OR kotak.com)",
            f"after:{one_year_ago} subject:(UPI OR NEFT OR IMPS OR \"account credited\" OR \"account debited\")",
        ]
        
        all_message_ids = set()
        for query in queries:
            try:
                result = (
                    service.users()
                    .messages()
                    .list(userId="me", q=query, maxResults=50)
                    .execute()
                )
                for msg in result.get("messages", []):
                    all_message_ids.add(msg["id"])
            except Exception as exc:
                logger.warning("Gmail query failed for '%s': %s", query, exc)
        
        messages = [{"id": msg_id} for msg_id in list(all_message_ids)[:50]]  # Limit to 50 total
        total = len(messages)
        logger.info("Gmail sync found %d unique messages for user %s (from %d queries)", total, user_id, len(queries))

        await conn.execute(
            "UPDATE spendsense.gmail_sync_job SET status='syncing', progress=0, updated_at=NOW() WHERE job_id=$1",
            job_id,
        )

        for index, message in enumerate(messages, start=1):
            msg = (
                service.users()
                .messages()
                .get(userId="me", id=message["id"], format="raw")
                .execute()
            )
            raw_email = base64.urlsafe_b64decode(msg["raw"].encode("utf-8"))
            try:
                records = parse_email_payload(
                    raw_email,
                    f"gmail-{message['id']}.eml",
                    alerts_only=True,
                )
                if records:
                    logger.info("Parsed %d transactions from Gmail message %s", len(records), message["id"])
                    await persist_records_async(
                        conn,
                        user_id,
                        records,
                        source_label=f"gmail-{message['id']}",
                        broadcast=True,
                    )
                # Silently skip emails with no transaction content (expected for most emails)
            except Exception as exc:  # pragma: no cover - logging safeguard
                # Only log as warning for unexpected errors (not "no content found" errors)
                error_msg = str(exc)
                if "password protected" in error_msg.lower():
                    logger.debug("Skipping password-protected PDF in message %s", message["id"])
                elif "no supported attachments" in error_msg.lower() or "no recognizable alert" in error_msg.lower():
                    # Expected - most emails aren't transaction alerts
                    pass
                else:
                    logger.warning("Failed parsing Gmail message %s: %s", message["id"], exc)
            progress = int((index / max(total, 1)) * 100)
            await conn.execute(
                "UPDATE spendsense.gmail_sync_job SET progress=$2, updated_at=NOW() WHERE job_id=$1",
                job_id,
                progress,
            )

        await conn.execute(
            "UPDATE spendsense.gmail_sync_job SET status='completed', progress=100, updated_at=NOW() WHERE job_id=$1",
            job_id,
        )
    except Exception as exc:  # pragma: no cover - catch-all
        logger.exception("Gmail sync failed: %s", exc)
        if conn:
            await conn.execute(
                "UPDATE spendsense.gmail_sync_job SET status='failed', error=$2, updated_at=NOW() WHERE job_id=$1",
                job_id,
                str(exc),
            )
    finally:
        if conn:
            await conn.close()


@celery_app.task(name="gmail.process_pubsub")
def process_gmail_pubsub_message(email_address: str, history_id: int) -> None:
    """Process a Gmail push notification (Pub/Sub)."""
    asyncio.run(_process_pubsub(email_address, history_id))


async def _process_pubsub(email_address: str, history_id: int) -> None:
    conn: asyncpg.Connection | None = None
    try:
        conn = await asyncpg.connect(str(settings.postgres_dsn), statement_cache_size=0)
        row = await conn.fetchrow(
            """
            SELECT
                gc.user_id,
                gc.access_token,
                gc.refresh_token,
                gw.history_id AS last_history_id
            FROM spendsense.gmail_connection gc
            LEFT JOIN spendsense.gmail_watch gw ON gw.user_id = gc.user_id
            WHERE gc.email_address = $1
            """,
            email_address,
        )
        if not row:
            logger.warning("No Gmail connection found for email %s", email_address)
            return

        user_id = str(row["user_id"])
        last_history_id = row.get("last_history_id")

        creds = Credentials(
            token=row["access_token"],
            refresh_token=row["refresh_token"],
            token_uri=str(settings.gmail_token_uri),
            client_id=settings.gmail_client_id,
            client_secret=settings.gmail_client_secret,
            scopes=["https://www.googleapis.com/auth/gmail.readonly"],
        )
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
            await conn.execute(
                """
                UPDATE spendsense.gmail_connection
                SET access_token=$2, token_expiry=$3, updated_at=NOW()
                WHERE user_id=$1
                """,
                user_id,
                creds.token,
                datetime.utcnow() + timedelta(seconds=3600),
            )

        service = build("gmail", "v1", credentials=creds, cache_discovery=False)

        message_ids: list[str] = []
        if last_history_id:
            try:
                history_resp = (
                    service.users()
                    .history()
                    .list(
                        userId="me",
                        startHistoryId=str(last_history_id),
                        historyTypes=["messageAdded"],
                        labelIds=["INBOX"],
                    )
                    .execute()
                )
                for history_record in history_resp.get("history", []):
                    for msg_added in history_record.get("messagesAdded", []):
                        message_ids.append(msg_added["message"]["id"])
            except Exception as exc:
                logger.warning(
                    "Failed to fetch Gmail history for %s: %s", email_address, exc
                )
                await conn.execute(
                    "UPDATE spendsense.gmail_watch SET history_id=$2, updated_at=NOW() WHERE user_id=$1",
                    user_id,
                    str(history_id),
                )
                return
        else:
            result = (
                service.users()
                .messages()
                .list(userId="me", q="in:inbox", maxResults=10)
                .execute()
            )
            message_ids = [msg["id"] for msg in result.get("messages", [])]

        if not message_ids:
            await conn.execute(
                "UPDATE spendsense.gmail_watch SET history_id=$2, updated_at=NOW() WHERE user_id=$1",
                user_id,
                str(history_id),
            )
            return

        for message_id in message_ids:
            await _process_single_push_message(conn, user_id, service, message_id, history_id)

        await conn.execute(
            "UPDATE spendsense.gmail_watch SET history_id=$2, updated_at=NOW() WHERE user_id=$1",
            user_id,
            str(history_id),
        )
    except Exception:
        logger.exception("Failed processing Pub/Sub message for %s", email_address)
        raise
    finally:
        if conn:
            await conn.close()


async def _process_single_push_message(
    conn: asyncpg.Connection,
    user_id: str,
    service,
    message_id: str,
    history_id: int,
) -> None:
    should_process = await mark_message_started(conn, user_id, message_id, history_id)
    if not should_process:
        return

    try:
        msg = (
            service.users()
            .messages()
            .get(userId="me", id=message_id, format="raw")
            .execute()
        )
        raw_email = base64.urlsafe_b64decode(msg["raw"].encode("utf-8"))
        records = parse_email_payload(
            raw_email,
            f"gmail-{message_id}.eml",
            alerts_only=True,
        )
        if records:
            await persist_records_async(
                conn,
                user_id,
                records,
                source_label=f"gmail-{message_id}",
                broadcast=True,
            )
        await mark_message_result(
            conn,
            user_id,
            message_id,
            success=True,
            error=None,
        )
    except Exception as exc:
        await mark_message_result(
            conn,
            user_id,
            message_id,
            success=False,
            error=str(exc),
        )
        raise




