from __future__ import annotations

import json
from typing import Any, Dict

import redis

from app.core.config import get_settings

settings = get_settings()
_redis = redis.from_url(str(settings.redis_url))


def broadcast_transaction_created(user_id: str, transaction: Dict[str, Any]) -> None:
    """Publish a transaction.created event for the given user."""
    message = {
        "type": "transaction.created",
        "user_id": user_id,
        "transaction": transaction,
    }
    _redis.publish(f"user:{user_id}:events", json.dumps(message))


