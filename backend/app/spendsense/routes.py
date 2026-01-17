import os
from typing import Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from asyncpg import Pool

from app.auth.dependencies import get_current_user
from app.auth.models import AuthenticatedUser
from app.dependencies.database import get_db_pool
from .models import (
    SourceType,
    SpendSenseKPI,
    StagingRecord,
    TransactionCreate,
    TransactionListResponse,
    TransactionRecord,
    TransactionUpdate,
    UploadBatch,
    UploadBatchCreate,
    CategoryResponse,
    SubcategoryResponse,
    AvailableMonthsResponse,
)
from .etl.parsers import SpendSenseParseError
from .service import SpendSenseService

router = APIRouter(prefix="/v1/spendsense", tags=["spendsense"])


def get_service(pool=Depends(get_db_pool)) -> SpendSenseService:
    return SpendSenseService(pool)


@router.post("/batches", response_model=UploadBatch, summary="Create upload batch")
async def create_batch(
    payload: UploadBatchCreate,
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> UploadBatch:
    return await service.create_upload_batch(user.user_id, payload)


@router.post(
    "/uploads/file",
    response_model=UploadBatch,
    summary="Upload statement file (csv/xls/xlsx/pdf)",
)
async def upload_statement(
    file: UploadFile = File(...),
    password: str | None = Form(None),
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> UploadBatch:
    import logging
    logger = logging.getLogger(__name__)
    
    logger.info(f"Upload request received: filename={file.filename}, user_id={user.user_id}, size={file.size if hasattr(file, 'size') else 'unknown'}")
    
    try:
        contents = await file.read()
        file_size = len(contents)
        logger.info(f"File read successfully: {file_size} bytes")
        
        if file_size == 0:
            raise HTTPException(status_code=400, detail="Uploaded file is empty")
        
        if file_size > 50 * 1024 * 1024:  # 50MB limit
            raise HTTPException(status_code=413, detail="File size exceeds 50MB limit")
        
        result = await service.enqueue_file_ingest(
            user_id=user.user_id,
            filename=file.filename or "unknown",
            file_bytes=contents,
            source_type=SourceType.FILE,
            pdf_password=password,
        )
        
        logger.info(f"Upload batch created successfully: upload_id={result.upload_id}, batch_id={result.upload_id}")
        return result
    except HTTPException:
        raise
    except SpendSenseParseError as exc:
        logger.error(f"Parse error during upload: {exc}")
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.error(f"Unexpected error during upload: {exc}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(exc)}") from exc


@router.post("/staging", response_model=StagingRecord, summary="Stage raw transaction")
async def stage_transaction(
    record: StagingRecord,
    service: SpendSenseService = Depends(get_service),
) -> StagingRecord:
    return await service.stage_record(record)


@router.get("/kpis", response_model=SpendSenseKPI, summary="SpendSense KPI snapshot")
async def get_kpis(
    month: str | None = Query(None, description="Month filter in YYYY-MM format (e.g., 2025-11). If not provided, returns latest available month."),
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> SpendSenseKPI:
    return await service.get_kpis(user.user_id, month=month)


@router.get("/kpis/available-months", response_model=AvailableMonthsResponse, summary="Get available months with transaction data")
async def get_available_months(
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> AvailableMonthsResponse:
    """Return list of available months in YYYY-MM format, sorted descending."""
    months = await service.get_available_months(user.user_id)
    return AvailableMonthsResponse(data=months)


@router.post(
    "/kpis/refresh",
    summary="Refresh KPI materialized views",
    status_code=200,
)
async def refresh_kpi_views(
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> dict[str, str]:
    """Refresh materialized views for KPI calculations."""
    await service.refresh_materialized_views(user.user_id)
    return {"status": "success", "message": "Materialized views refreshed"}


@router.get("/insights", response_model=dict[str, Any], summary="Get comprehensive spending insights")
async def get_insights(
    start_date: str | None = Query(None, description="Start date in YYYY-MM-DD format"),
    end_date: str | None = Query(None, description="End date in YYYY-MM-DD format"),
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> dict[str, Any]:
    """Get comprehensive insights including time-series, category breakdown, trends, and recurring transactions."""
    from datetime import datetime
    
    start = datetime.strptime(start_date, "%Y-%m-%d").date() if start_date else None
    end = datetime.strptime(end_date, "%Y-%m-%d").date() if end_date else None
    
    return await service.get_insights(user.user_id, start_date=start, end_date=end)


@router.get(
    "/batches/{batch_id}",
    response_model=UploadBatch,
    summary="Get upload batch status",
)
async def get_batch_status(
    batch_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> UploadBatch:
    batch = await service.get_batch_status(batch_id, user.user_id)
    if not batch:
        raise HTTPException(status_code=404, detail="Batch not found")
    return batch


@router.post(
    "/transactions",
    response_model=TransactionRecord,
    summary="Create manual transaction",
    status_code=201,
)
async def create_transaction(
    data: TransactionCreate,
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> TransactionRecord:
    """Create a manual transaction."""
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        logger.info(f"Creating manual transaction for user {user.user_id}: merchant={data.merchant_name}, amount={data.amount}, direction={data.direction}")
        result = await service.create_manual_transaction(user.user_id, data)
        logger.info(f"Successfully created transaction {result.txn_id} for user {user.user_id}")
        return result
    except ValueError as exc:
        logger.warning(f"Validation error creating transaction for user {user.user_id}: {exc}")
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.error(f"Error creating manual transaction for user {user.user_id}: {exc}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to create transaction: {str(exc)}") from exc


@router.get(
    "/transactions",
    response_model=TransactionListResponse,
    summary="List effective transactions",
)
async def list_transactions(
    limit: int = Query(25, ge=1, le=200),
    offset: int = Query(0, ge=0),
    search: str | None = Query(None, max_length=120),
    category_code: str | None = Query(None),
    subcategory_code: str | None = Query(None),
    channel: str | None = Query(None),
    direction: str | None = Query(None, description="Filter by direction: debit or credit"),
    start_date: str | None = Query(None, description="Start date in YYYY-MM-DD format"),
    end_date: str | None = Query(None, description="End date in YYYY-MM-DD format"),
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> TransactionListResponse:
    transactions, total = await service.list_transactions(
        user.user_id,
        limit,
        offset,
        search=search,
        category_code=category_code,
        subcategory_code=subcategory_code,
        channel=channel,
        start_date=start_date,
        end_date=end_date,
        direction=direction,
    )
    # Calculate page and page_size from limit and offset
    page = (offset // limit) + 1 if limit > 0 else 1
    page_size = limit
    
    return TransactionListResponse(
        transactions=transactions,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.delete(
    "/data",
    summary="Delete all user transaction data",
    status_code=200,
)
async def delete_all_user_data(
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> dict[str, int]:
    """Delete all transaction data for the authenticated user. This is irreversible."""
    return await service.delete_all_user_data(user.user_id)


@router.put(
    "/transactions/{txn_id}",
    response_model=TransactionRecord,
    summary="Update transaction category/subcategory",
)
async def update_transaction(
    txn_id: str,
    update: TransactionUpdate,
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> TransactionRecord:
    """Update transaction category, subcategory, or transaction type via override."""
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        # Safely get txn_type - Pydantic v2 may raise AttributeError when accessing optional fields
        # Use model_dump() to safely get all fields as a dict, then access txn_type
        txn_type = None
        try:
            # Get dict representation of the model
            update_dict = update.model_dump() if hasattr(update, 'model_dump') else update.dict()
            txn_type = update_dict.get('txn_type')
        except (AttributeError, TypeError, ValueError):
            # If model_dump fails, try getattr as fallback
            try:
                txn_type = getattr(update, 'txn_type', None)
            except:
                txn_type = None
        
        logger.info(
            f"Route: update_transaction called - txn_id={txn_id}, user_id={user.user_id}, "
            f"category_code={update.category_code}, subcategory_code={update.subcategory_code}, "
            f"txn_type={txn_type}, merchant_name={update.merchant_name}, channel={update.channel}"
        )
        
        return await service.update_transaction(
            user_id=user.user_id,
            txn_id=txn_id,
            category_code=update.category_code,
            subcategory_code=update.subcategory_code,
            txn_type=txn_type,
            merchant_name=update.merchant_name,
            channel=update.channel,
        )
    except ValueError as exc:
        logger.warning(f"Transaction update failed (ValueError): {exc}")
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        logger.error(
            f"Transaction update failed with unexpected error: {exc}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update transaction: {str(exc)}"
        ) from exc


@router.delete(
    "/transactions/{txn_id}",
    summary="Delete a transaction",
    status_code=200,
)
async def delete_transaction(
    txn_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> dict[str, bool]:
    """Delete a single transaction."""
    deleted = await service.delete_transaction(user.user_id, txn_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return {"deleted": True}


@router.get(
    "/categories",
    summary="Get all categories",
)
async def get_categories(
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> list[CategoryResponse]:
    """Get all active categories (system + user's custom)."""
    return await service.get_categories(user_id=user.user_id)


@router.get(
    "/subcategories",
    summary="Get subcategories",
)
async def get_subcategories(
    category_code: str | None = Query(None, description="Filter by category code"),
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> list[SubcategoryResponse]:
    """Get all active subcategories, optionally filtered by category."""
    return await service.get_subcategories(category_code, user_id=user.user_id)


@router.post(
    "/categories",
    summary="Create custom category",
    status_code=201,
)
async def create_custom_category(
    category_code: str = Query(..., description="Category code (lowercase, no spaces)"),
    category_name: str = Query(..., description="Display name"),
    txn_type: str = Query("wants", description="Transaction type: income/needs/wants/assets"),
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> dict[str, str]:
    """Create a custom category for the authenticated user."""
    if txn_type not in ("income", "needs", "wants", "assets"):
        raise HTTPException(status_code=400, detail="Invalid txn_type")
    return await service.create_custom_category(
        user.user_id, category_code, category_name, txn_type
    )


@router.post(
    "/subcategories",
    summary="Create custom subcategory",
    status_code=201,
)
async def create_custom_subcategory(
    subcategory_code: str = Query(..., description="Subcategory code (lowercase, no spaces)"),
    subcategory_name: str = Query(..., description="Display name"),
    category_code: str = Query(..., description="Parent category code"),
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> dict[str, str]:
    """Create a custom subcategory for the authenticated user."""
    try:
        return await service.create_custom_subcategory(
            user.user_id, subcategory_code, subcategory_name, category_code
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/re-enrich",
    summary="Re-enrich all transactions",
    status_code=200,
)
async def re_enrich_transactions(
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> dict[str, int]:
    """Delete existing enriched records and re-run enrichment with updated merchant rules."""
    enriched_count = await service.re_enrich_transactions(user.user_id)
    return {"enriched_count": enriched_count}


@router.get(
    "/categories/predict",
    summary="Predict transaction category",
)
async def predict_category(
    description: str = Query(..., description="Transaction description"),
    amount: float = Query(..., description="Transaction amount"),
    merchant: str | None = Query(None, description="Merchant name (optional)"),
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
) -> dict[str, Any]:
    """
    Predict transaction category using rule-based matching and ML fallback.
    
    Flow:
    1. Try rule-based merchant_rules (fast, high precision)
    2. If no rule match, call ML model (TF-IDF + LogisticRegression)
    3. Final fallback to 'shopping' category
    
    The ML model prioritizes merchant names by repeating them in the text features,
    ensuring merchant names are given more weight in TF-IDF vectorization.
    """
    """
    Predict transaction category using rule-based matching and ML fallback.

    Flow:
    1. Try rule-based merchant_rules (fast, high precision)
    2. If no rule match, call ML model (TF-IDF + LogisticRegression)
    3. Final fallback to 'shopping' category
    """
    from app.spendsense.services.pg_rules_client import PGRulesClient
    from app.spendsense.services.ml_category_model import ml_predict_category

    conn = await pool.acquire()
    try:
        # 1) Rule-based matching (merchant_rules + dim_merchant + merchant_alias)
        rule_match = await PGRulesClient.match_merchant(
            conn,
            merchant_name=merchant,
            description=description,
            user_id=user.user_id,
            use_cache=True,
        )

        if rule_match and rule_match.get("category_code"):
            return {
                "category": rule_match.get("category_code"),
                "subcategory": rule_match.get("subcategory_code"),
                "confidence": rule_match.get("confidence", 0.9),
                "rule_id": str(rule_match.get("rule_id", "")) if rule_match.get("rule_id") else None,
                "merchant_id": str(rule_match.get("merchant_id", "")) if rule_match.get("merchant_id") else None,
                "method": "rule_based",
                "match_kind": rule_match.get("match_kind", "unknown"),
            }

        # 2) ML fallback
        ml_res = ml_predict_category(
            description=description,
            merchant=merchant,
            amount=amount,
        )

        if ml_res:
            return {
                "category": ml_res["category_code"],
                "subcategory": None,
                "confidence": ml_res["confidence"],
                "rule_id": None,
                "merchant_id": None,
                "method": "ml_fallback",
                "match_kind": None,
            }

        # 3) Final fallback
        return {
            "category": "shopping",
            "subcategory": None,
            "confidence": 0.4,
            "rule_id": None,
            "merchant_id": None,
            "method": "fallback",
            "match_kind": None,
        }
    finally:
        await pool.release(conn)


@router.get(
    "/ml/status",
    summary="Check ML model availability",
)
async def ml_status() -> dict[str, Any]:
    """Check if ML category prediction model is available."""
    from app.spendsense.services.ml_category_model import is_ml_available
    
    available = is_ml_available()
    return {
        "ml_available": available,
        "model_path": os.getenv("CATEGORY_MODEL_PATH", "models/category_model.joblib"),
    }

