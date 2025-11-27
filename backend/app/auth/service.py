from collections.abc import Mapping
from typing import Any, Final

import httpx

from app.core.config import Settings, get_settings
from .models import LoginRequest, LoginResponse

SUPABASE_TIMEOUT_SECONDS: Final[int] = 10


class SupabaseAuthService:
    """Client wrapper that calls Supabase Auth endpoints."""

    def __init__(self, settings: Settings | None = None) -> None:
        self._settings = settings or get_settings()

    async def sign_in_with_password(self, payload: LoginRequest) -> LoginResponse:
        """Delegate a password login attempt to Supabase."""

        json_body = {
            "email": payload.email,
            "password": payload.password.get_secret_value(),
        }
        response = await self._post(
            path="/auth/v1/token?grant_type=password",
            json=json_body,
        )
        return LoginResponse.model_validate(response)

    async def _post(self, path: str, json: Mapping[str, Any]) -> dict[str, Any]:
        url = f"{self._settings.supabase_url}{path}"
        headers = {
            "Content-Type": "application/json",
            "apikey": self._settings.supabase_anon_key,
            "Authorization": f"Bearer {self._settings.supabase_service_role_key}",
        }

        async with httpx.AsyncClient(timeout=SUPABASE_TIMEOUT_SECONDS) as client:
            response = await client.post(url, json=json, headers=headers)

        response.raise_for_status()
        return response.json()

