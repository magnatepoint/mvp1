from fastapi import Depends, HTTPException, WebSocket, WebSocketException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.security import SupabaseJWTError, decode_supabase_jwt
from .models import AuthenticatedUser

http_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(http_bearer),
) -> AuthenticatedUser:
    """Extract and validate the Supabase JWT from the Authorization header."""

    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
        )

    token = credentials.credentials

    try:
        return decode_supabase_jwt(token)
    except SupabaseJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc


async def get_current_user_ws(websocket: WebSocket) -> AuthenticatedUser:
    """Authenticate a WebSocket connection using ?token=..."""
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4401)
        raise WebSocketException(code=status.WS_1008_POLICY_VIOLATION, reason="Missing token")

    try:
        return decode_supabase_jwt(token)
    except SupabaseJWTError as exc:
        await websocket.close(code=4401)
        raise WebSocketException(
            code=status.WS_1008_POLICY_VIOLATION,
            reason=str(exc),
        ) from exc

