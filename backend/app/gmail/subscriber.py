"""Gmail Pub/Sub subscriber worker that pulls messages and processes them."""

from __future__ import annotations

import asyncio
import base64
import json
import logging
import os
from datetime import datetime, timedelta

import asyncpg
from google.auth.transport.requests import Request
from google.cloud import pubsub_v1  # type: ignore[import-untyped]
from google.oauth2 import service_account  # type: ignore[import-untyped]
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from app.core.config import get_settings
from app.gmail.message_store import mark_message_result, mark_message_started
from app.gmail.persistence import persist_records_async
from app.spendsense.etl.parsers import parse_email_payload

settings = get_settings()
logger = logging.getLogger(__name__)

# Set up Google Cloud credentials for Pub/Sub
if settings.google_application_credentials:
    creds_path = settings.google_application_credentials
    # If relative path, make it absolute relative to backend directory
    if not os.path.isabs(creds_path):
        # __file__ is app/gmail/subscriber.py, so go up 3 levels to get backend/
        backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        # Remove leading ./ if present
        creds_path = creds_path.lstrip("./")
        creds_path = os.path.join(backend_dir, creds_path)
    # Normalize path (removes ./ and resolves ..)
    creds_path = os.path.normpath(creds_path)
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = creds_path




async def _persist_records_async(conn: asyncpg.Connection, user_id: str, records: list[dict]) -> None:
    await persist_records_async(
        conn,
        user_id,
        records,
        source_label="gmail-realtime",
        broadcast=True,
    )


async def process_gmail_notification(email_address: str, history_id: str) -> None:
    """Process a Gmail notification: fetch new messages and parse transactions."""
    conn: asyncpg.Connection | None = None
    try:
        conn = await asyncpg.connect(str(settings.postgres_dsn), statement_cache_size=0)
        
        # 1. Look up user by email address, get their Gmail credentials
        watch_row = await conn.fetchrow(
            """
            SELECT gc.user_id, gc.access_token, gc.refresh_token, gw.history_id as last_history_id
            FROM spendsense.gmail_connection gc
            LEFT JOIN spendsense.gmail_watch gw ON gw.user_id = gc.user_id
            WHERE gc.email_address = $1
            """,
            email_address,
        )
        if not watch_row:
            logger.warning("No Gmail connection found for email %s", email_address)
            return
        
        user_id = str(watch_row["user_id"])
        last_history_id = watch_row.get("last_history_id")
        
        # 2. Build Gmail service with their credentials
        creds = Credentials(
            token=watch_row["access_token"],
            refresh_token=watch_row["refresh_token"],
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
        
        # 3. Call history.list to fetch new messages since last historyId
        message_ids = []
        if last_history_id:
            try:
                history = (
                    service.users()
                    .history()
                    .list(
                        userId="me",
                        startHistoryId=last_history_id,
                        historyTypes=["messageAdded"],
                        labelIds=["INBOX"],
                    )
                    .execute()
                )
                for history_record in history.get("history", []):
                    for msg_added in history_record.get("messagesAdded", []):
                        message_ids.append(msg_added["message"]["id"])
            except Exception as exc:
                logger.warning("Failed to fetch history for %s: %s", email_address, exc)
                # If historyId is too old, just update to current
                await conn.execute(
                    "UPDATE spendsense.gmail_watch SET history_id=$2, updated_at=NOW() WHERE user_id=$1",
                    user_id,
                    history_id,
                )
                return
        else:
            # First time, get recent messages
            result = (
                service.users()
                .messages()
                .list(userId="me", q="in:inbox", maxResults=10)
                .execute()
            )
            message_ids = [msg["id"] for msg in result.get("messages", [])]
        
        if not message_ids:
            logger.info("No new messages for %s", email_address)
            # Update history_id even if no messages
            await conn.execute(
                "UPDATE spendsense.gmail_watch SET history_id=$2, updated_at=NOW() WHERE user_id=$1",
                user_id,
                history_id,
            )
            return
        
        logger.info("Processing %d new messages for %s", len(message_ids), email_address)
        
        # 4. For each new message, fetch it and run your transaction parser
        history_seq = int(history_id)
        for msg_id in message_ids:
            try:
                should_process = await mark_message_started(conn, user_id, msg_id, history_seq)
                if not should_process:
                    continue
                msg = (
                    service.users()
                    .messages()
                    .get(userId="me", id=msg_id, format="raw")
                    .execute()
                )
                raw_email = base64.urlsafe_b64decode(msg["raw"].encode("utf-8"))
                records = parse_email_payload(
                    raw_email,
                    f"gmail-{msg_id}.eml",
                    alerts_only=True,
                )
                if records:
                    logger.info("Parsed %d transactions from Gmail message %s", len(records), msg_id)
                    await _persist_records_async(conn, user_id, records)
                await mark_message_result(
                    conn,
                    user_id,
                    msg_id,
                    success=True,
                    error=None,
                )
            except Exception as exc:
                logger.warning("Failed to process Gmail message %s: %s", msg_id, exc)
                await mark_message_result(
                    conn,
                    user_id,
                    msg_id,
                    success=False,
                    error=str(exc),
                )
        
        # Update history_id
        await conn.execute(
            "UPDATE spendsense.gmail_watch SET history_id=$2, updated_at=NOW() WHERE user_id=$1",
            user_id,
            history_id,
        )
        
    except Exception as exc:
        logger.exception("Failed to process Gmail notification for %s: %s", email_address, exc)
    finally:
        if conn:
            await conn.close()


def handle_message(message: pubsub_v1.subscriber.message.Message) -> None:
    """Handle a Pub/Sub message from Gmail notifications."""
    try:
        # Decode message data
        data = json.loads(message.data.decode("utf-8"))
        email_address = data.get("emailAddress")
        history_id = data.get("historyId")
        
        if not email_address or not history_id:
            logger.warning("Invalid notification format: %s", data)
            message.ack()
            return
        
        logger.info("Received Gmail notification for %s, historyId=%s", email_address, history_id)
        
        # Process notification asynchronously
        asyncio.run(process_gmail_notification(email_address, history_id))
        
        # Acknowledge message
        message.ack()
        
    except Exception as exc:
        logger.exception("Error handling Pub/Sub message: %s", exc)
        # Nack message to retry later
        message.nack()


def start_subscriber_worker() -> None:
    """Start the Pub/Sub subscriber worker that pulls messages."""
    if not settings.gcp_project_id:
        logger.error("GCP_PROJECT_ID not set, cannot start subscriber worker")
        return
    
    # Check for credentials
    if not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS") and not os.path.exists(
        os.path.expanduser("~/.config/gcloud/application_default_credentials.json")
    ):
        logger.error(
            "Google Cloud credentials not found. Please set up Application Default Credentials:\n"
            "  Option 1: gcloud auth application-default login\n"
            "  Option 2: Set GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json\n"
            "  Option 3: Set GOOGLE_APPLICATION_CREDENTIALS in backend/.env"
        )
        return
    
    PROJECT_ID = settings.gcp_project_id
    SUB_ID = f"{settings.gmail_pubsub_topic}-sub"
    
    try:
        subscriber = pubsub_v1.SubscriberClient()
        sub_path = subscriber.subscription_path(PROJECT_ID, SUB_ID)
        
        logger.info("Starting Gmail Pub/Sub subscriber worker for subscription %s", sub_path)
        
        # Subscribe and keep process alive
        streaming_pull_future = subscriber.subscribe(sub_path, callback=handle_message)
        
        try:
            streaming_pull_future.result()  # Keep process alive
        except KeyboardInterrupt:
            streaming_pull_future.cancel()
            logger.info("Subscriber worker stopped")
    except Exception as exc:
        logger.exception("Failed to start subscriber worker: %s", exc)
        logger.error(
            "\nTo fix this, set up Google Cloud credentials:\n"
            "  1. Run: gcloud auth application-default login\n"
            "  2. Or set GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json\n"
            "  3. Or add GOOGLE_APPLICATION_CREDENTIALS to backend/.env"
        )


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    start_subscriber_worker()

