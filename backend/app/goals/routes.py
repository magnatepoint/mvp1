"""API routes for Goals module."""

import logging
import math
from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

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
from .signals_repository import GoalSignalsRepository
from .suggestions_repository import GoalSuggestionsRepository

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1/goals", tags=["goals"])


def get_service(pool: Pool = Depends(get_db_pool)) -> GoalsService:
    """Get GoalsService instance."""
    return GoalsService(pool)


def safe_user_id(user: AuthenticatedUser) -> UUID:
    """Safely convert user_id string to UUID."""
    try:
        return UUID(user.user_id)
    except (ValueError, TypeError) as e:
        logger.error(f"Invalid user_id format: {user.user_id}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid user ID format: {str(e)}",
        ) from e


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
        recommended = await service.get_recommended_goals(safe_user_id(user))
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
        context = await service.get_life_context(safe_user_id(user))
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
        result = await service.save_life_context(safe_user_id(user), context.model_dump())
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
        await service.save_life_context(safe_user_id(user), payload.context.model_dump())

        # Create goals
        goals_data = [goal.model_dump() for goal in payload.selected_goals]
        created = await service.create_goals(safe_user_id(user), goals_data)

        return GoalsSubmitResponse(goals_created=created)
    except Exception as e:
        logger.error(f"Error submitting goals: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to submit goals",
        ) from e


@router.get("/progress", response_model=GoalsProgressResponse, summary="Get goals progress")
async def get_goals_progress(
    user: AuthenticatedUser = Depends(get_current_user),
    service: GoalsService = Depends(get_service),
) -> GoalsProgressResponse:
    """Get progress for all active goals with enhanced projections."""
    try:
        progress = await service.get_goals_progress(safe_user_id(user))
        logger.debug(f"Service returned {len(progress) if progress else 0} progress items")
        
        if not progress:
            # Return empty list if no progress data
            return GoalsProgressResponse(goals=[])
        
        result = []
        for idx, item in enumerate(progress):
            try:
                logger.debug(f"Processing progress item {idx}: {item}")
                
                # Ensure goal_id is a valid UUID string
                goal_id_val = item.get("goal_id")
                if not goal_id_val:
                    logger.warning(f"Skipping progress item {idx} with missing goal_id: {item}")
                    continue
                
                goal_id_str = str(goal_id_val)
                try:
                    goal_id_uuid = UUID(goal_id_str)
                except (ValueError, TypeError) as uuid_error:
                    logger.warning(f"Invalid goal_id format {goal_id_str}: {uuid_error}")
                    continue
                
                # Ensure goal_name is present
                goal_name = item.get("goal_name")
                if not goal_name:
                    logger.warning(f"Skipping progress item {idx} with missing goal_name")
                    continue
                
                # Convert projected_completion_date string to date
                projected_date = None
                proj_date = item.get("projected_completion_date")
                if proj_date:
                    if isinstance(proj_date, str) and proj_date.strip():
                        try:
                            projected_date = date.fromisoformat(proj_date)
                        except (ValueError, TypeError) as date_error:
                            logger.debug(f"Could not parse date {proj_date}: {date_error}")
                            projected_date = None
                    elif isinstance(proj_date, date):
                        projected_date = proj_date
                
                # Ensure milestones are valid integers
                milestones_list = []
                for m in item.get("milestones", []):
                    try:
                        if isinstance(m, int):
                            milestones_list.append(m)
                        elif isinstance(m, str) and m.isdigit():
                            milestones_list.append(int(m))
                    except (ValueError, TypeError):
                        continue
                
                # Ensure all required numeric fields are valid and finite
                progress_pct = item.get("progress_pct")
                if progress_pct is None:
                    progress_pct = 0.0
                else:
                    try:
                        progress_pct = float(progress_pct)
                        if not math.isfinite(progress_pct):
                            progress_pct = 0.0
                        # Clamp to 0-100 range
                        progress_pct = max(0.0, min(100.0, progress_pct))
                    except (ValueError, TypeError):
                        logger.warning(f"Invalid progress_pct for item {idx}: {progress_pct}")
                        progress_pct = 0.0
                
                current_savings_close = item.get("current_savings_close")
                if current_savings_close is None:
                    current_savings_close = 0.0
                else:
                    try:
                        current_savings_close = float(current_savings_close)
                        if not math.isfinite(current_savings_close):
                            current_savings_close = 0.0
                        current_savings_close = max(0.0, current_savings_close)
                    except (ValueError, TypeError):
                        logger.warning(f"Invalid current_savings_close for item {idx}: {current_savings_close}")
                        current_savings_close = 0.0
                
                remaining_amount = item.get("remaining_amount")
                if remaining_amount is None:
                    remaining_amount = 0.0
                else:
                    try:
                        remaining_amount = float(remaining_amount)
                        if not math.isfinite(remaining_amount):
                            remaining_amount = 0.0
                        remaining_amount = max(0.0, remaining_amount)
                    except (ValueError, TypeError):
                        logger.warning(f"Invalid remaining_amount for item {idx}: {remaining_amount}")
                        remaining_amount = 0.0
                
                progress_dict = {
                    "goal_id": goal_id_uuid,
                    "goal_name": str(goal_name),
                    "progress_pct": progress_pct,
                    "current_savings_close": current_savings_close,
                    "remaining_amount": remaining_amount,
                    "projected_completion_date": projected_date,
                    "milestones": milestones_list,
                }
                
                # Validate the dict before creating Pydantic model
                try:
                    progress_item = GoalProgressItem(**progress_dict)
                    result.append(progress_item)
                    logger.debug(f"Successfully processed progress item {idx} for goal {goal_id_str}")
                except Exception as validation_error:
                    logger.error(f"Pydantic validation error for progress item {idx} ({goal_id_str}): {validation_error}")
                    logger.error(f"Progress dict that failed: {progress_dict}")
                    # Skip invalid items but continue processing others
                    continue
            except Exception as item_error:
                logger.error(f"Error processing progress item {idx} ({item.get('goal_id')}): {item_error}", exc_info=True)
                # Skip invalid items but continue processing others
                continue
        
        logger.debug(f"Returning {len(result)} valid progress items")
        
        # Return Pydantic model directly - FastAPI will handle serialization
        return GoalsProgressResponse(goals=result)
    except Exception as e:
        logger.error(f"Error fetching goals progress: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch goals progress: {str(e)}",
        ) from e


@router.get("/signals", summary="Get goal signals")
async def get_goal_signals(
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
) -> list[dict]:
    """Get recent goal signals (drift, overspend, etc.) for the user."""
    try:
        async with pool.acquire() as conn:
            signals_repo = GoalSignalsRepository(conn)
            signals = await signals_repo.get_recent_signals(safe_user_id(user))
            # Convert UUIDs to strings for JSON serialization
            for signal in signals:
                if signal.get("id"):
                    signal["id"] = str(signal["id"])
                if signal.get("goal_id"):
                    signal["goal_id"] = str(signal["goal_id"]) if signal.get("goal_id") else None
                if signal.get("created_at"):
                    signal["created_at"] = signal["created_at"].isoformat()
            return signals
    except Exception as e:
        logger.error(f"Error fetching goal signals: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch goal signals",
        ) from e


@router.get("/suggestions", summary="Get goal suggestions")
async def get_goal_suggestions(
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
) -> list[dict]:
    """Get open goal suggestions (actionable recommendations) for the user."""
    try:
        async with pool.acquire() as conn:
            suggestions_repo = GoalSuggestionsRepository(conn)
            suggestions = await suggestions_repo.list_open_suggestions(safe_user_id(user))
            # Convert UUIDs to strings for JSON serialization
            for suggestion in suggestions:
                if suggestion.get("id"):
                    suggestion["id"] = str(suggestion["id"])
                if suggestion.get("goal_id"):
                    suggestion["goal_id"] = str(suggestion["goal_id"]) if suggestion.get("goal_id") else None
                if suggestion.get("created_at"):
                    suggestion["created_at"] = suggestion["created_at"].isoformat()
                if suggestion.get("updated_at"):
                    suggestion["updated_at"] = suggestion["updated_at"].isoformat()
            return suggestions
    except Exception as e:
        logger.error(f"Error fetching goal suggestions: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch goal suggestions",
        ) from e


@router.get("", response_model=list[GoalResponse], summary="Get all user goals")
async def get_goals(
    user: AuthenticatedUser = Depends(get_current_user),
    service: GoalsService = Depends(get_service),
) -> list[GoalResponse]:
    """Get all active goals for the user."""
    try:
        goals = await service.get_user_goals(safe_user_id(user))
        result = []
        for goal in goals:
            try:
                # Convert goal_id string to UUID and ensure proper types
                target_date_val = goal.get("target_date")
                if target_date_val:
                    if isinstance(target_date_val, str):
                        try:
                            target_date_val = date.fromisoformat(target_date_val)
                        except (ValueError, TypeError):
                            target_date_val = None
                    elif not isinstance(target_date_val, date):
                        target_date_val = None
                
                goal_dict = {
                    "goal_id": UUID(str(goal["goal_id"])),
                    "goal_category": str(goal.get("goal_category", "")),
                    "goal_name": str(goal.get("goal_name", "")),
                    "goal_type": str(goal.get("goal_type", "user_defined")),
                    "linked_txn_type": goal.get("linked_txn_type"),
                    "estimated_cost": float(goal.get("estimated_cost", 0.0)),
                    "target_date": target_date_val,
                    "current_savings": float(goal.get("current_savings", 0.0)),
                    "importance": goal.get("importance"),
                    "priority_rank": goal.get("priority_rank"),
                    "status": str(goal.get("status", "active")),
                    "notes": goal.get("notes"),
                    "created_at": str(goal.get("created_at", "")) if goal.get("created_at") else "",
                    "updated_at": str(goal.get("updated_at", "")) if goal.get("updated_at") else "",
                }
                result.append(GoalResponse(**goal_dict))
            except Exception as goal_error:
                logger.error(f"Error processing goal {goal.get('goal_id')}: {goal_error}", exc_info=True)
                # Skip invalid goals but continue processing others
                continue
        return result
    except Exception as e:
        logger.error(f"Error fetching goals: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch goals: {str(e)}",
        ) from e


@router.get("/{goal_id}", response_model=GoalResponse, summary="Get a single goal")
async def get_goal(
    goal_id: UUID,
    user: AuthenticatedUser = Depends(get_current_user),
    service: GoalsService = Depends(get_service),
) -> GoalResponse:
    """Get a single goal by ID."""
    try:
        goal_dict = await service.get_user_goal(safe_user_id(user), goal_id)
        if not goal_dict:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found"
            )
        # Convert goal_id string to UUID and ensure proper types
        target_date_val = goal_dict.get("target_date")
        if target_date_val and isinstance(target_date_val, str):
            try:
                target_date_val = date.fromisoformat(target_date_val)
            except (ValueError, TypeError):
                target_date_val = None
        
        response_dict = {
            "goal_id": UUID(str(goal_dict["goal_id"])),
            "goal_category": str(goal_dict["goal_category"]),
            "goal_name": str(goal_dict["goal_name"]),
            "goal_type": str(goal_dict["goal_type"]),
            "linked_txn_type": goal_dict.get("linked_txn_type"),
            "estimated_cost": float(goal_dict["estimated_cost"]),
            "target_date": target_date_val if isinstance(target_date_val, (date, type(None))) else None,
            "current_savings": float(goal_dict["current_savings"]),
            "importance": goal_dict.get("importance"),
            "priority_rank": goal_dict.get("priority_rank"),
            "status": str(goal_dict["status"]),
            "notes": goal_dict.get("notes"),
            "created_at": str(goal_dict["created_at"]) if goal_dict.get("created_at") else "",
            "updated_at": str(goal_dict["updated_at"]) if goal_dict.get("updated_at") else "",
        }
        return GoalResponse(**response_dict)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching goal: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch goal",
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
        updated = await service.update_goal(safe_user_id(user), goal_id, updates_dict)
        if not updated:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found"
            )
        # Convert goal_id string to UUID and ensure proper types
        target_date_val = updated.get("target_date")
        if target_date_val and isinstance(target_date_val, str):
            try:
                target_date_val = date.fromisoformat(target_date_val)
            except (ValueError, TypeError):
                target_date_val = None
        
        response_dict = {
            "goal_id": UUID(str(updated["goal_id"])),
            "goal_category": str(updated["goal_category"]),
            "goal_name": str(updated["goal_name"]),
            "goal_type": str(updated["goal_type"]),
            "linked_txn_type": updated.get("linked_txn_type"),
            "estimated_cost": float(updated["estimated_cost"]),
            "target_date": target_date_val if isinstance(target_date_val, (date, type(None))) else None,
            "current_savings": float(updated["current_savings"]),
            "importance": updated.get("importance"),
            "priority_rank": updated.get("priority_rank"),
            "status": str(updated["status"]),
            "notes": updated.get("notes"),
            "created_at": str(updated["created_at"]) if updated.get("created_at") else "",
            "updated_at": str(updated["updated_at"]) if updated.get("updated_at") else "",
        }
        return GoalResponse(**response_dict)
    except HTTPException:
        raise
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
        result = await service.delete_goal(safe_user_id(user), goal_id)
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


class SuggestionStatusUpdate(BaseModel):
    """Request model for updating suggestion status."""
    status: str


@router.patch("/suggestions/{suggestion_id}", summary="Update suggestion status")
async def update_suggestion_status(
    suggestion_id: UUID,
    payload: SuggestionStatusUpdate,
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
) -> dict:
    """Update a suggestion's status (accepted/dismissed)."""
    try:
        if payload.status not in ["accepted", "dismissed"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Status must be 'accepted' or 'dismissed'",
            )
        
        async with pool.acquire() as conn:
            suggestions_repo = GoalSuggestionsRepository(conn)
            await suggestions_repo.update_status(safe_user_id(user), suggestion_id, payload.status)
            return {"status": "updated", "suggestion_id": str(suggestion_id), "new_status": payload.status}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating suggestion status: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update suggestion status",
        ) from e

