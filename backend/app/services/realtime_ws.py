from __future__ import annotations

from typing import Dict, Set

from fastapi import WebSocket

_connections: Dict[str, Set[WebSocket]] = {}


async def register_ws(user_id: str, websocket: WebSocket) -> None:
    """Register a WebSocket connection for a user. The connection must already be accepted."""
    _connections.setdefault(user_id, set()).add(websocket)


async def unregister_ws(user_id: str, websocket: WebSocket) -> None:
    conns = _connections.get(user_id)
    if not conns:
        return
    conns.discard(websocket)
    if not conns:
        _connections.pop(user_id, None)


async def send_to_user(user_id: str, message: dict) -> None:
    conns = _connections.get(user_id)
    if not conns:
        return
    stale = []
    for ws in list(conns):
        try:
            await ws.send_json(message)
        except Exception:
            stale.append(ws)
    for ws in stale:
        await unregister_ws(user_id, ws)


