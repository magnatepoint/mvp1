from fastapi import APIRouter

router = APIRouter()


@router.get("/", summary="API health check")
async def health_check() -> dict[str, str]:
    """Return a simple health status payload."""
    return {"status": "ok"}

