from fastapi import APIRouter, Depends

from .dependencies import get_current_user
from .models import AuthenticatedUser, LoginRequest, LoginResponse, SessionResponse
from .service import SupabaseAuthService

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=LoginResponse, summary="Supabase password login")
async def login(payload: LoginRequest) -> LoginResponse:
    """Authenticate via Supabase Auth and return the session tokens."""

    service = SupabaseAuthService()
    return await service.sign_in_with_password(payload)


@router.get("/session", response_model=SessionResponse, summary="Validate Supabase session")
async def session(user: AuthenticatedUser = Depends(get_current_user)) -> SessionResponse:
    """Validate the provided Supabase JWT and return the associated user."""

    return SessionResponse(
        user_id=user.user_id,
        email=user.email,
        role=user.role,
    )

