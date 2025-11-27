"""Gmail Pub/Sub setup and management for real-time notifications."""

from __future__ import annotations

import logging
from datetime import datetime, timedelta

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from google.cloud import pubsub_v1  # type: ignore[import-untyped]

from app.core.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)


def setup_gmail_watch(
    user_id: str,
    access_token: str,
    refresh_token: str,
) -> dict[str, str]:
    """Set up Gmail watch with Pub/Sub for real-time notifications.
    
    Creates a pull subscription that a worker will poll.
    
    Returns:
        dict with 'watch_id', 'history_id', 'topic_name', 'expires_at'
    """
    if not settings.gcp_project_id:
        raise ValueError("GCP_PROJECT_ID must be set for real-time Gmail sync")
    
    # Initialize Gmail API client
    creds = Credentials(
        token=access_token,
        refresh_token=refresh_token,
        token_uri=str(settings.gmail_token_uri),
        client_id=settings.gmail_client_id,
        client_secret=settings.gmail_client_secret,
        scopes=["https://www.googleapis.com/auth/gmail.readonly"],
    )
    if creds.expired and creds.refresh_token:
        creds.refresh(Request())
    
    service = build("gmail", "v1", credentials=creds, cache_discovery=False)
    
    # Get user's email address
    profile = service.users().getProfile(userId="me").execute()
    email_address = profile.get("emailAddress")
    
    # Create or get Pub/Sub topic (shared across all users)
    topic_name = f"projects/{settings.gcp_project_id}/topics/{settings.gmail_pubsub_topic}"
    publisher = pubsub_v1.PublisherClient()
    try:
        publisher.get_topic(request={"topic": topic_name})
        logger.info("Pub/Sub topic %s already exists", topic_name)
    except Exception:
        # Topic doesn't exist, create it
        topic_path = publisher.topic_path(settings.gcp_project_id, settings.gmail_pubsub_topic)
        publisher.create_topic(request={"name": topic_path})
        logger.info("Created Pub/Sub topic %s", topic_name)
    
    # Create pull subscription (shared across all users - worker will filter by email)
    subscription_name = f"{settings.gmail_pubsub_topic}-sub"
    subscriber = pubsub_v1.SubscriberClient()
    subscription_path = subscriber.subscription_path(settings.gcp_project_id, subscription_name)
    topic_path = publisher.topic_path(settings.gcp_project_id, settings.gmail_pubsub_topic)
    
    try:
        subscriber.get_subscription(request={"subscription": subscription_path})
        logger.info("Subscription %s already exists", subscription_name)
    except Exception:
        # Create pull subscription (no push_config = pull subscription)
        subscriber.create_subscription(
            request={
                "name": subscription_path,
                "topic": topic_path,
                "ack_deadline_seconds": 60,
            }
        )
        logger.info("Created pull subscription %s", subscription_name)
    
    # Set up Gmail watch (expires in 7 days, max allowed)
    watch_request = {
        "topicName": topic_name,
        "labelIds": ["INBOX"],  # or more specific labels if you want
    }
    
    watch_response = service.users().watch(userId="me", body=watch_request).execute()
    
    history_id = watch_response.get("historyId")
    expiration_ms = watch_response.get("expiration", 604800000)  # Default 7 days in ms
    expires_at = datetime.utcnow() + timedelta(milliseconds=expiration_ms)
    
    return {
        "watch_id": history_id,  # Use historyId as watch identifier
        "history_id": history_id,
        "topic_name": topic_name,
        "expires_at": expires_at.isoformat(),
        "email_address": email_address,
    }

