from datetime import datetime, timezone

import jwt
from jwt import InvalidTokenError

from app.core.config import get_settings
from app.auth.models import AuthenticatedUser


class SupabaseJWTError(RuntimeError):
    """Raised when a Supabase JWT fails verification."""


def decode_supabase_jwt(token: str) -> AuthenticatedUser:
    """Validate a Supabase JWT and return the parsed claims."""

    settings = get_settings()

    try:
        payload = jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            audience="authenticated",
            leeway=600,  # 10 minutes leeway for clock skew
        )
    except InvalidTokenError as exc:
        raise SupabaseJWTError("Invalid Supabase JWT") from exc

    claims = AuthenticatedUser(**payload)
    _ensure_not_expired(claims.exp)
    return claims


def _ensure_not_expired(exp_timestamp: int) -> None:
    expires_at = datetime.fromtimestamp(exp_timestamp, tz=timezone.utc)
    if expires_at <= datetime.now(tz=timezone.utc):
        raise SupabaseJWTError("Supabase JWT has expired")

