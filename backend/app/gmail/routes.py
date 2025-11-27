from __future__ import annotations

import base64
import json
import logging
import jwt
from datetime import datetime, timedelta
from urllib.parse import urlencode

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel

logger = logging.getLogger(__name__)

from app.auth.dependencies import get_current_user
from app.auth.models import AuthenticatedUser
from app.core.config import get_settings
from app.dependencies.database import get_db_pool
from app.gmail.models import GmailJobStatus
from app.gmail.service import GmailService
from app.gmail.tasks import process_gmail_pubsub_message, sync_gmail_inbox_task
from app.gmail.pubsub import setup_gmail_watch

settings = get_settings()
router = APIRouter(prefix="/gmail", tags=["gmail"])


class PubSubEnvelope(BaseModel):
    message: dict
    subscription: str | None = None


def _state_token(user_id: str) -> str:
    payload = {"user_id": user_id, "exp": datetime.utcnow() + timedelta(minutes=15)}
    token = jwt.encode(payload, settings.supabase_jwt_secret, algorithm="HS256")
    return token


def _decode_state(state: str) -> str:
    try:
        payload = jwt.decode(state, settings.supabase_jwt_secret, algorithms=["HS256"])
        return str(payload["user_id"])
    except jwt.PyJWTError as exc:  # pragma: no cover - defensive
        raise HTTPException(status_code=400, detail="Invalid state token") from exc


def get_gmail_service(pool=Depends(get_db_pool)) -> GmailService:
    return GmailService(pool)


@router.get("/connect")
async def connect_gmail(
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict[str, str]:
    state = _state_token(user.user_id)
    params = {
        "client_id": settings.gmail_client_id,
        "redirect_uri": str(settings.gmail_redirect_uri),
        "response_type": "code",
        "scope": "https://www.googleapis.com/auth/gmail.readonly",
        "access_type": "offline",
        "prompt": "consent",
        "state": state,
        "include_granted_scopes": "true",
    }
    auth_url = f"https://accounts.google.com/o/oauth2/v2/auth?{urlencode(params)}"
    return {"auth_url": auth_url}


@router.get("/oauth/callback", include_in_schema=False, response_class=HTMLResponse)
async def gmail_oauth_callback(
    code: str = Query(...),
    state: str = Query(...),
    service: GmailService = Depends(get_gmail_service),
):
    user_id = _decode_state(state)
    token_payload = {
        "code": code,
        "client_id": settings.gmail_client_id,
        "client_secret": settings.gmail_client_secret,
        "redirect_uri": str(settings.gmail_redirect_uri),
        "grant_type": "authorization_code",
    }

    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(str(settings.gmail_token_uri), data=token_payload)
    if response.status_code != 200:
        detail = "Failed to exchange authorization code"
        try:
            error_body = response.json()
            detail = f"{detail}: {error_body}"
        except ValueError:  # pragma: no cover - debugging aid
            detail = f"{detail}: {response.text}"
        raise HTTPException(status_code=400, detail=detail)

    token_data = response.json()
    refresh_token = token_data.get("refresh_token")
    if not refresh_token:
        raise HTTPException(status_code=400, detail="Google did not return a refresh token.")

    # Get email address from Gmail profile
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build
    
    temp_creds = Credentials(
        token=token_data["access_token"],
        refresh_token=refresh_token,
        token_uri=str(settings.gmail_token_uri),
        client_id=settings.gmail_client_id,
        client_secret=settings.gmail_client_secret,
        scopes=["https://www.googleapis.com/auth/gmail.readonly"],
    )
    temp_service = build("gmail", "v1", credentials=temp_creds, cache_discovery=False)
    profile = temp_service.users().getProfile(userId="me").execute()
    email_address = profile.get("emailAddress")
    
    await service.upsert_connection(
        user_id=user_id,
        access_token=token_data["access_token"],
        refresh_token=refresh_token,
        expires_in=token_data.get("expires_in", 3600),
        email_address=email_address,
    )
    job_id = await service.create_sync_job(user_id, status="queued")
    sync_gmail_inbox_task.delay(job_id=job_id)

    return HTMLResponse(
        "<html><body><h3>Gmail connected.</h3><p>You can close this tab and return to the app.</p></body></html>"
    )


@router.post("/sync", response_model=GmailJobStatus)
async def trigger_sync(
    user: AuthenticatedUser = Depends(get_current_user),
    service: GmailService = Depends(get_gmail_service),
):
    connection = await service.get_connection(user.user_id)
    if not connection:
        raise HTTPException(status_code=400, detail="Connect Gmail before syncing.")
    job_id = await service.create_sync_job(user.user_id, status="queued")
    sync_gmail_inbox_task.delay(job_id=job_id)
    job = await service.get_latest_job(user.user_id)
    return job  # type: ignore[return-value]


@router.get("/sync/status", response_model=GmailJobStatus | None)
async def sync_status(
    user: AuthenticatedUser = Depends(get_current_user),
    service: GmailService = Depends(get_gmail_service),
):
    return await service.get_latest_job(user.user_id)


@router.post("/enable-realtime")
async def enable_realtime_sync(
    user: AuthenticatedUser = Depends(get_current_user),
    service: GmailService = Depends(get_gmail_service),
):
    """Enable real-time Gmail sync via Pub/Sub pull subscriptions."""
    if not settings.gcp_project_id:
        raise HTTPException(
            status_code=400,
            detail="GCP_PROJECT_ID must be configured for real-time sync",
        )
    
    connection = await service.get_connection(user.user_id)
    if not connection:
        raise HTTPException(status_code=400, detail="Connect Gmail before enabling real-time sync.")
    
    # Set up Gmail watch with Pub/Sub (synchronous function)
    watch_info = setup_gmail_watch(
        user_id=user.user_id,
        access_token=connection["access_token"],
        refresh_token=connection["refresh_token"],
    )
    
    # Store watch info in database
    expires_at = datetime.fromisoformat(watch_info["expires_at"])
    await service.upsert_watch(
        user_id=user.user_id,
        watch_id=watch_info["watch_id"],
        history_id=watch_info["history_id"],
        topic_name=watch_info["topic_name"],
        expires_at=expires_at,
    )
    
    # Update email address if provided
    if watch_info.get("email_address"):
        await service.upsert_connection(
            user_id=user.user_id,
            access_token=connection["access_token"],
            refresh_token=connection["refresh_token"],
            expires_in=3600,  # Dummy value, won't update expiry
            email_address=watch_info["email_address"],
        )
    
    return {
        "status": "enabled",
        "expires_at": watch_info["expires_at"],
        "message": "Real-time sync enabled. Gmail will push notifications for new emails.",
    }


@router.post("/webhook", include_in_schema=False)
async def gmail_pubsub_webhook(envelope: PubSubEnvelope) -> dict[str, str]:
    """Google Pub/Sub push entrypoint for Gmail notifications."""
    try:
        data_b64 = envelope.message["data"]
        payload = json.loads(base64.b64decode(data_b64).decode("utf-8"))
    except Exception as exc:
        logger.exception("Failed to decode Pub/Sub payload: %s", exc)
        raise HTTPException(status_code=400, detail="Invalid Pub/Sub envelope") from exc

    email_address = payload.get("emailAddress")
    history_id = payload.get("historyId")
    if not email_address or not history_id:
        raise HTTPException(status_code=400, detail="Missing emailAddress/historyId")

    process_gmail_pubsub_message.delay(
        email_address=email_address,
        history_id=int(history_id),
    )
    return {"status": "ok"}




