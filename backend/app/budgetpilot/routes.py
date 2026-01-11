"""BudgetPilot API routes."""

from datetime import date
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.auth.dependencies import AuthenticatedUser, get_current_user
from app.dependencies.database import Pool, get_db_pool
from .service import BudgetService

router = APIRouter(prefix="/v1/budget", tags=["budget"])


def get_service(pool: Pool = Depends(get_db_pool)) -> BudgetService:
    """Dependency to get BudgetService."""
    return BudgetService(pool)


class BudgetCommitRequest(BaseModel):
    """Request model for committing a budget."""

    plan_code: str
    month: date | None = None
    goal_allocations: dict[str, float] | None = None
    notes: str | None = None


@router.get("/recommendations", summary="Get budget recommendations")
async def get_recommendations(
    month: date | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
    service: BudgetService = Depends(get_service),
) -> dict[str, Any]:
    """
    Get top 3 budget plan recommendations for the user.
    
    Returns recommendations with:
    - plan_code, name, description
    - needs_budget_pct, wants_budget_pct, savings_budget_pct
    - score, recommendation_reason
    - goal_preview (allocation preview per goal)
    """
    recommendations = await service.get_recommendations(UUID(user.user_id), month)
    return {"recommendations": recommendations}


@router.post("/commit", summary="Commit to a budget plan")
async def commit_budget(
    payload: BudgetCommitRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    service: BudgetService = Depends(get_service),
) -> dict[str, Any]:
    """
    Commit to a budget plan for a month.
    
    If goal_allocations is provided, it overrides auto-allocation.
    Otherwise, allocations are computed automatically based on goal priorities.
    """
    month = payload.month or date.today().replace(day=1)
    committed = await service.commit_budget(
        UUID(user.user_id),
        month,
        payload.plan_code,
        payload.goal_allocations,
        payload.notes,
    )
    return {"status": "committed", "budget": committed}


@router.get("/commit", summary="Get committed budget")
async def get_committed_budget(
    month: date | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
    service: BudgetService = Depends(get_service),
) -> dict[str, Any]:
    """Get user's committed budget for a month (defaults to current month)."""
    committed = await service.get_committed_budget(UUID(user.user_id), month)
    if not committed:
        return {"status": "no_commitment", "budget": None}
    return {"status": "committed", "budget": committed}


@router.get("/variance", summary="Get budget variance (actuals vs planned)")
async def get_budget_variance(
    month: date | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
    service: BudgetService = Depends(get_service),
) -> dict[str, Any]:
    """
    Get monthly aggregate showing actual spending vs planned budget.
    
    Returns:
    - income_amt
    - needs_amt, planned_needs_amt, variance_needs_amt
    - wants_amt, planned_wants_amt, variance_wants_amt
    - assets_amt, planned_assets_amt, variance_assets_amt
    """
    aggregate = await service.get_month_aggregate(UUID(user.user_id), month)
    if not aggregate:
        return {"status": "no_data", "aggregate": None}
    return {"status": "ok", "aggregate": aggregate}

