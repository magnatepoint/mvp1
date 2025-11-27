"""Routes for ML training and prediction."""

from typing import Any, Dict

from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Pool

from app.auth.dependencies import get_current_user
from app.auth.models import AuthenticatedUser
from app.dependencies.database import get_db_pool

from .trainer import train_ml_model

router = APIRouter(prefix="/spendsense/ml", tags=["spendsense-ml"])


@router.post(
    "/train",
    summary="Train ML model from user's transaction data",
    status_code=200,
)
async def train_model(
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
) -> Dict[str, Any]:
    """Train ML model from the authenticated user's transaction data and feedback."""
    conn = await pool.acquire()
    try:
        result = await train_ml_model(conn, user_id=user.user_id, model_type="combined")
        if "error" in result:
            raise HTTPException(status_code=400, detail=result["error"])
        return result
    finally:
        await pool.release(conn)


@router.post(
    "/train/global",
    summary="Train global ML model from all transaction data",
    status_code=200,
)
async def train_global_model(
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
) -> Dict[str, Any]:
    """Train global ML model from all users' transaction data (admin only - for now, any user)."""
    conn = await pool.acquire()
    try:
        result = await train_ml_model(conn, user_id=None, model_type="combined")
        if "error" in result:
            raise HTTPException(status_code=400, detail=result["error"])
        return result
    finally:
        await pool.release(conn)
