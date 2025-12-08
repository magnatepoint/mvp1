from fastapi import APIRouter

router = APIRouter()


@router.get("/", summary="API health check")
async def health_check() -> dict[str, str]:
    """Return a simple health status payload."""
    return {"status": "ok"}


@router.get("/health", summary="API health check (alias)")
async def health_check_alias() -> dict[str, str]:
    """Return a simple health status payload."""
    return {"status": "ok"}

