from __future__ import annotations

import json

import redis.asyncio as aioredis  # type: ignore[reportMissingImports]

from app.core.config import get_settings
from app.services.realtime_ws import send_to_user

settings = get_settings()


async def redis_events_listener() -> None:
    """Listen for Redis pub/sub events and fan out to WebSocket clients."""
    redis = aioredis.from_url(str(settings.redis_url))
    pubsub = redis.pubsub()
    await pubsub.psubscribe("user:*:events")

    async for message in pubsub.listen():
        if message["type"] not in ("message", "pmessage"):
            continue

        data = message["data"]
        if isinstance(data, bytes):
            try:
                payload = json.loads(data.decode("utf-8"))
            except json.JSONDecodeError:
                continue
        elif isinstance(data, str):
            try:
                payload = json.loads(data)
            except json.JSONDecodeError:
                continue
        else:
            continue

        user_id = payload.get("user_id")
        if not user_id:
            continue

        await send_to_user(user_id, payload)


