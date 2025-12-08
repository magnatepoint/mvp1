from __future__ import annotations

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, WebSocketException, status

from app.auth.dependencies import get_current_user_ws
from app.core.security import SupabaseJWTError, decode_supabase_jwt
from app.services.realtime_ws import register_ws, unregister_ws

router = APIRouter()


async def _handle_websocket_connection(websocket: WebSocket, user):
    """Shared WebSocket connection handler."""
    user_id = str(user.user_id)
    await register_ws(user_id, websocket)
    try:
        await websocket.send_json({"type": "connected", "user_id": user_id})
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        await unregister_ws(user_id, websocket)


async def _authenticate_websocket(websocket: WebSocket):
    """Authenticate WebSocket connection after accepting it."""
    import logging
    logger = logging.getLogger(__name__)
    
    token = websocket.query_params.get("token")
    if not token:
        logger.warning("WebSocket connection rejected: missing token")
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Missing token")
        raise WebSocketException(
            code=status.WS_1008_POLICY_VIOLATION,
            reason="Missing token"
        )
    
    try:
        user = decode_supabase_jwt(token)
        logger.info(f"WebSocket authenticated for user: {user.user_id}")
        return user
    except SupabaseJWTError as exc:
        logger.error(f"WebSocket authentication failed: {exc}", exc_info=True)
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason=str(exc))
        raise WebSocketException(
            code=status.WS_1008_POLICY_VIOLATION,
            reason=str(exc)
        ) from exc
    except Exception as exc:
        logger.error(f"WebSocket authentication unexpected error: {exc}", exc_info=True)
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Authentication error")
        raise WebSocketException(
            code=status.WS_1008_POLICY_VIOLATION,
            reason="Authentication error"
        ) from exc


@router.websocket("/ws")
async def ws_root(websocket: WebSocket):
    """WebSocket endpoint at /ws (alias for /ws/transactions)."""
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        await websocket.accept()
        logger.debug(f"WebSocket connection accepted from {websocket.client}")
        user = await _authenticate_websocket(websocket)
        await _handle_websocket_connection(websocket, user)
    except WebSocketException as exc:
        # Already closed in _authenticate_websocket
        logger.debug(f"WebSocket connection closed: {exc.reason}")
        pass
    except Exception as exc:
        logger.error(f"WebSocket connection error: {exc}", exc_info=True)
        try:
            await websocket.close(code=status.WS_1011_INTERNAL_ERROR, reason="Internal server error")
        except:
            pass


@router.websocket("/ws/transactions")
async def transactions_ws(websocket: WebSocket):
    """WebSocket endpoint for transaction updates."""
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        await websocket.accept()
        logger.debug(f"WebSocket connection accepted from {websocket.client}")
        user = await _authenticate_websocket(websocket)
        await _handle_websocket_connection(websocket, user)
    except WebSocketException as exc:
        # Already closed in _authenticate_websocket
        logger.debug(f"WebSocket connection closed: {exc.reason}")
        pass
    except Exception as exc:
        logger.error(f"WebSocket connection error: {exc}", exc_info=True)
        try:
            await websocket.close(code=status.WS_1011_INTERNAL_ERROR, reason="Internal server error")
        except:
            pass

