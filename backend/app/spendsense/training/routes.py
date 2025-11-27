"""API routes for training system."""

from __future__ import annotations

import asyncio
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse

from app.auth.dependencies import get_current_user
from app.auth.models import AuthenticatedUser
from app.core.config import get_settings
from app.dependencies.database import get_db_pool
from app.spendsense.training.trainer import run_training

settings = get_settings()
router = APIRouter(prefix="/spendsense/training", tags=["training"])


@router.post("/run")
async def run_training_endpoint(
    apply: bool = False,
    user: AuthenticatedUser = Depends(get_current_user),
) -> JSONResponse:
    """Run training on sample bank files.
    
    Args:
        apply: If True, apply learned merchants/rules to database. If False, only generate report.
    """
    # Find sample_bank directory (relative to project root)
    # Path from: backend/app/spendsense/training/routes.py -> project root
    sample_dir = Path(__file__).resolve().parents[4] / "sample_bank"
    
    if not sample_dir.exists():
        raise HTTPException(
            status_code=404,
            detail=f"Sample bank directory not found: {sample_dir}",
        )
    
    try:
        report = await run_training(str(sample_dir), apply=apply)
        return JSONResponse(report)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Training failed: {str(exc)}") from exc


@router.get("/status")
async def training_status(
    user: AuthenticatedUser = Depends(get_current_user),
) -> JSONResponse:
    """Get training status and sample file information."""
    sample_dir = Path(__file__).resolve().parents[4] / "sample_bank"
    
    if not sample_dir.exists():
        return JSONResponse({
            "status": "error",
            "message": f"Sample directory not found: {sample_dir}",
        })
    
    # Count sample files
    sample_files = []
    for ext in [".xls", ".xlsx", ".csv", ".pdf"]:
        sample_files.extend(sample_dir.glob(f"*{ext}"))
        sample_files.extend(sample_dir.glob(f"**/*{ext}"))
    
    return JSONResponse({
        "status": "ready",
        "sample_directory": str(sample_dir),
        "sample_files_count": len(sample_files),
        "sample_files": [f.name for f in sample_files[:20]],  # First 20
    })

