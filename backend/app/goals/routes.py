"""API routes for Goals module."""

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from app.auth.dependencies import get_current_user
from app.auth.models import AuthenticatedUser
from app.dependencies.database import get_db_pool
from asyncpg import Pool

from .models import (
    GoalCatalogItem,
    GoalDetailRequest,
    GoalProgressItem,
    GoalResponse,
    GoalUpdateRequest,
    GoalsProgressResponse,
    GoalsSubmitRequest,
    GoalsSubmitResponse,
    LifeContextRequest,
)
from .service import GoalsService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1/goals", tags=["goals"])


def get_service(pool: Pool = Depends(get_db_pool)) -> GoalsService:
    """Get GoalsService instance."""
    return GoalsService(pool)


@router.get("/catalog", response_model=list[GoalCatalogItem], summary="Get goal catalog")
async def get_catalog(
    service: GoalsService = Depends(get_service),
) -> list[GoalCatalogItem]:
    """Get the goal catalog from master table."""
    try:
        catalog = await service.get_goal_catalog()
        return [GoalCatalogItem(**item) for item in catalog]
    except Exception as e:
        logger.error(f"Error fetching goal catalog: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch goal catalog",
        ) from e


@router.get("/recommended", summary="Get recommended goals")
async def get_recommended_goals(
    user: AuthenticatedUser = Depends(get_current_user),
    service: GoalsService = Depends(get_service),
) -> list[GoalCatalogItem]:
    """Get recommended goals based on life context and transaction patterns."""
    try:
        recommended = await service.get_recommended_goals(user.user_id)
        return [GoalCatalogItem(**item) for item in recommended]
    except Exception as e:
        logger.error(f"Error fetching recommended goals: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch recommended goals",
        ) from e


@router.get("/context", summary="Get user life context")
async def get_life_context(
    user: AuthenticatedUser = Depends(get_current_user),
    service: GoalsService = Depends(get_service),
) -> dict:
    """Get user's life context."""
    try:
        context = await service.get_life_context(user.user_id)
        if not context:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Life context not found"
            )
        return context
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching life context: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch life context",
        ) from e


@router.put("/context", summary="Update user life context")
async def update_life_context(
    context: LifeContextRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    service: GoalsService = Depends(get_service),
) -> dict:
    """Update user's life context."""
    try:
        result = await service.save_life_context(user.user_id, context.model_dump())
        return result
    except Exception as e:
        logger.error(f"Error updating life context: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update life context",
        ) from e


@router.post("/submit", response_model=GoalsSubmitResponse, summary="Submit goals")
async def submit_goals(
    payload: GoalsSubmitRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    service: GoalsService = Depends(get_service),
) -> GoalsSubmitResponse:
    """Submit life context and selected goals."""
    try:
        # Save life context
        await service.save_life_context(user.user_id, payload.context.model_dump())

        # Create goals
        goals_data = [goal.model_dump() for goal in payload.selected_goals]
        created = await service.create_goals(user.user_id, goals_data)

        return GoalsSubmitResponse(goals_created=created)
    except Exception as e:
        logger.error(f"Error submitting goals: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to submit goals",
        ) from e


@router.get("", response_model=list[GoalResponse], summary="Get all user goals")
async def get_goals(
    user: AuthenticatedUser = Depends(get_current_user),
    service: GoalsService = Depends(get_service),
) -> list[GoalResponse]:
    """Get all active goals for the user."""
    try:
        goals = await service.get_user_goals(user.user_id)
        return [GoalResponse(**goal) for goal in goals]
    except Exception as e:
        logger.error(f"Error fetching goals: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch goals",
        ) from e


@router.put("/{goal_id}", response_model=GoalResponse, summary="Update a goal")
async def update_goal(
    goal_id: UUID,
    updates: GoalUpdateRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    service: GoalsService = Depends(get_service),
) -> GoalResponse:
    """Update a goal."""
    try:
        updates_dict = updates.model_dump(exclude_unset=True)
        updated = await service.update_goal(user.user_id, goal_id, updates_dict)
        return GoalResponse(**updated)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(e)
        ) from e
    except Exception as e:
        logger.error(f"Error updating goal: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update goal",
        ) from e


@router.delete("/{goal_id}", summary="Delete a goal")
async def delete_goal(
    goal_id: UUID,
    user: AuthenticatedUser = Depends(get_current_user),
    service: GoalsService = Depends(get_service),
) -> dict:
    """Soft delete a goal (set status to cancelled)."""
    try:
        result = await service.delete_goal(user.user_id, goal_id)
        return result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(e)
        ) from e
    except Exception as e:
        logger.error(f"Error deleting goal: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete goal",
        ) from e


@router.get("/progress", response_model=GoalsProgressResponse, summary="Get goals progress")
async def get_goals_progress(
    user: AuthenticatedUser = Depends(get_current_user),
    service: GoalsService = Depends(get_service),
) -> GoalsProgressResponse:
    """Get progress for all active goals from latest snapshot."""
    try:
        progress = await service.get_goals_progress(user.user_id)
        return GoalsProgressResponse(goals=[GoalProgressItem(**item) for item in progress])
    except Exception as e:
        logger.error(f"Error fetching goals progress: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch goals progress",
        ) from e

