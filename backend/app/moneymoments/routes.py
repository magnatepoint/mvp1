"""MoneyMoments API routes."""

from datetime import date
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.auth.dependencies import AuthenticatedUser, get_current_user
from app.dependencies.database import Pool, get_db_pool
from .service import MoneyMomentsService

router = APIRouter(prefix="/v1/moneymoments", tags=["moneymoments"])


def get_service(pool: Pool = Depends(get_db_pool)) -> MoneyMomentsService:
    """Dependency to get MoneyMomentsService."""
    return MoneyMomentsService(pool)


class NudgeInteractionRequest(BaseModel):
    """Request model for logging nudge interaction."""

    event_type: str  # 'view', 'click', 'dismiss'
    metadata: dict[str, Any] | None = None


@router.get("/moments", summary="Get money moments (behavioral insights)")
async def get_moments(
    month: str | None = None,
    all_months: bool = False,
    user: AuthenticatedUser = Depends(get_current_user),
    service: MoneyMomentsService = Depends(get_service),
) -> dict[str, Any]:
    """
    Get behavioral insights (money moments) for the user.
    
    Returns list of moments with:
    - habit_id, value, label, insight_text, confidence
    
    Args:
        month: Optional month filter (YYYY-MM format). If not provided and all_months=False, returns latest month only.
        all_months: If True, returns all months for the user. If False and month is not provided, returns latest month only.
    """
    import logging
    logger = logging.getLogger(__name__)
    
    logger.info(f"GET /moments - user_id={user.user_id}, month={month}, all_months={all_months}")
    moments = await service.get_moments(UUID(user.user_id), month, all_months)
    logger.info(f"Returning {len(moments)} moments for user {user.user_id}")
    return {"moments": moments}


@router.post("/moments/compute", summary="Compute money moments for a month")
async def compute_moments(
    target_month: str | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
    service: MoneyMomentsService = Depends(get_service),
) -> dict[str, Any]:
    """
    Compute and store money moments for the user for a specific month.
    If month is not provided, uses current month.
    
    Args:
        target_month: Optional month in "YYYY-MM" or "YYYY-MM-DD" format. If not provided, uses current month.
    
    Returns:
    - status: "computed" or "no_data" 
    - moments: list of computed moments
    - count: number of moments
    - message: informational message
    """
    import logging
    from datetime import datetime
    logger = logging.getLogger(__name__)
    
    if target_month is None:
        target_month_date = date.today().replace(day=1)
    else:
        # Parse the month string - support both "YYYY-MM" and "YYYY-MM-DD" formats
        try:
            if len(target_month) == 7:  # "YYYY-MM" format
                target_month_date = datetime.strptime(target_month, "%Y-%m").date().replace(day=1)
            else:  # "YYYY-MM-DD" format
                target_month_date = datetime.strptime(target_month, "%Y-%m-%d").date().replace(day=1)
        except ValueError as e:
            logger.error(f"Invalid date format '{target_month}': {e}")
            return {
                "status": "error",
                "moments": [],
                "count": 0,
                "message": f"Invalid date format '{target_month}'. Expected 'YYYY-MM' or 'YYYY-MM-DD'."
            }
    
    target_month = target_month_date
    
    user_uuid = UUID(user.user_id)
    logger.info(f"POST /moments/compute - user_id={user.user_id} (UUID: {user_uuid}), target_month={target_month}, email={user.email}")
    moments = await service.compute_moments(user_uuid, target_month)
    logger.info(f"Computed {len(moments)} moments for user {user.user_id}, month {target_month}")
    
    if not moments:
        logger.warning(f"No moments computed for user {user.user_id}, month {target_month}. This usually means no transactions exist for this month.")
        return {
            "status": "no_data",
            "moments": [],
            "count": 0,
            "message": f"No transactions found for {target_month.strftime('%B %Y')}. Please ensure you have uploaded transaction data for this month. You can upload transactions in the SpendSense tab."
        }
    
    return {
        "status": "computed",
        "moments": moments,
        "count": len(moments),
        "message": f"Successfully computed {len(moments)} money moments for {target_month.strftime('%B %Y')}"
    }


@router.get("/nudges", summary="Get recent nudges")
async def get_nudges(
    limit: int = 20,
    user: AuthenticatedUser = Depends(get_current_user),
    service: MoneyMomentsService = Depends(get_service),
) -> dict[str, Any]:
    """Get recent nudges delivered to the user."""
    import logging
    logger = logging.getLogger(__name__)
    
    logger.info(f"GET /nudges - user_id={user.user_id}, limit={limit}")
    nudges = await service.get_nudges(UUID(user.user_id), limit)
    logger.info(f"Returning {len(nudges)} nudges for user {user.user_id}")
    return {"nudges": nudges}


@router.post("/nudges/{delivery_id}/interact", summary="Log nudge interaction")
async def log_nudge_interaction(
    delivery_id: UUID,
    payload: NudgeInteractionRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    service: MoneyMomentsService = Depends(get_service),
) -> dict[str, Any]:
    """Log user interaction with a nudge (view, click, dismiss)."""
    await service.log_interaction(
        UUID(user.user_id),
        delivery_id,
        payload.event_type,
        payload.metadata,
    )
    return {"status": "logged"}


@router.post("/nudges/evaluate", summary="Evaluate rules and queue nudges")
async def evaluate_nudges(
    as_of_date: date | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
    service: MoneyMomentsService = Depends(get_service),
) -> dict[str, Any]:
    """
    Evaluate nudge rules for the user and create candidates.
    Typically called by a scheduled job, but can be triggered manually.
    """
    result = await service.evaluate_and_queue_nudges(UUID(user.user_id), as_of_date)
    return result


@router.post("/nudges/process", summary="Process pending nudges and deliver")
async def process_nudges(
    limit: int = 10,
    user: AuthenticatedUser | None = Depends(get_current_user),
    service: MoneyMomentsService = Depends(get_service),
) -> dict[str, Any]:
    """
    Process pending nudge candidates and deliver them.
    Typically called by a scheduled job.
    If user is provided, only processes for that user.
    """
    user_id = UUID(user.user_id) if user else None
    delivered = await service.process_pending_nudges(user_id, limit)
    return {"status": "processed", "delivered": delivered, "count": len(delivered)}


@router.post("/signals/compute", summary="Compute daily signal for nudge evaluation")
async def compute_signal(
    as_of_date: date | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
    service: MoneyMomentsService = Depends(get_service),
) -> dict[str, Any]:
    """
    Compute daily signal for a user.
    This aggregates spending data needed for nudge rule evaluation.
    """
    signal = await service.compute_daily_signal(UUID(user.user_id), as_of_date)
    if not signal:
        return {"status": "no_data", "signal": None}
    return {"status": "computed", "signal": signal}


@router.get("/moments/diagnose", summary="Diagnose why moments aren't computing")
async def diagnose_moments(
    user: AuthenticatedUser = Depends(get_current_user),
    service: MoneyMomentsService = Depends(get_service),
) -> dict[str, Any]:
    """
    Diagnostic endpoint to check why moments aren't being computed.
    Returns information about transactions, user_id, and potential issues.
    """
    import logging
    logger = logging.getLogger(__name__)
    
    user_uuid = UUID(user.user_id)
    logger.info(f"GET /moments/diagnose - user_id={user.user_id} (UUID: {user_uuid}), email={user.email}")
    
    # Check transactions
    async with service.pool.acquire() as conn:
        # Count total transactions for this user
        total_txns = await conn.fetchval(
            "SELECT COUNT(*) FROM spendsense.vw_txn_effective WHERE user_id = $1",
            user_uuid
        )
        
        # Get date range of transactions
        date_range = await conn.fetchrow(
            """
            SELECT 
                MIN(txn_date) as min_date,
                MAX(txn_date) as max_date,
                COUNT(*) as count
            FROM spendsense.vw_txn_effective
            WHERE user_id = $1
            """,
            user_uuid
        )
        
        # Check if moments exist
        moments_count = await conn.fetchval(
            "SELECT COUNT(*) FROM moneymoments.mm_user_moments WHERE user_id = $1",
            user_uuid
        )
        
        # Check recent months with transactions
        recent_months = await conn.fetch(
            """
            SELECT 
                DATE_TRUNC('month', txn_date)::text as month,
                COUNT(*) as txn_count
            FROM spendsense.vw_txn_effective
            WHERE user_id = $1
              AND txn_date >= CURRENT_DATE - INTERVAL '12 months'
            GROUP BY DATE_TRUNC('month', txn_date)
            ORDER BY month DESC
            LIMIT 12
            """,
            user_uuid
        )
    
    result = {
        "user_id": str(user_uuid),
        "email": user.email,
        "total_transactions": total_txns or 0,
        "moments_count": moments_count or 0,
        "date_range": {
            "min": str(date_range["min_date"]) if date_range and date_range["min_date"] else None,
            "max": str(date_range["max_date"]) if date_range and date_range["max_date"] else None,
        } if date_range else None,
        "recent_months": [
            {"month": row["month"], "transaction_count": row["txn_count"]}
            for row in recent_months
        ],
        "diagnosis": []
    }
    
    # Add diagnosis
    if total_txns == 0:
        result["diagnosis"].append("No transactions found for this user. Please upload transaction data.")
    elif moments_count == 0:
        result["diagnosis"].append("Transactions exist but moments haven't been computed. Try clicking 'Compute Moments'.")
        if date_range:
            result["diagnosis"].append(f"Transactions span from {date_range['min_date']} to {date_range['max_date']}")
    else:
        result["diagnosis"].append(f"Found {moments_count} moments. Everything looks good!")
    
    return result

