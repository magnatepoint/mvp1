from __future__ import annotations

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect

from app.auth.dependencies import get_current_user_ws
from app.services.realtime_ws import register_ws, unregister_ws

router = APIRouter()


@router.websocket("/ws/transactions")
async def transactions_ws(websocket: WebSocket, user=Depends(get_current_user_ws)):
    user_id = str(user.user_id)
    await register_ws(user_id, websocket)
    try:
        await websocket.send_json({"type": "connected", "user_id": user_id})
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        await unregister_ws(user_id, websocket)

