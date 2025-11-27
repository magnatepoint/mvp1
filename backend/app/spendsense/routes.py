from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile

from app.auth.dependencies import get_current_user
from app.auth.models import AuthenticatedUser
from app.dependencies.database import get_db_pool
from .models import (
    SourceType,
    SpendSenseKPI,
    StagingRecord,
    TransactionListResponse,
    TransactionRecord,
    TransactionUpdate,
    UploadBatch,
    UploadBatchCreate,
    CategoryResponse,
    SubcategoryResponse,
)
from .etl.parsers import SpendSenseParseError
from .service import SpendSenseService

router = APIRouter(prefix="/spendsense", tags=["spendsense"])


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
    contents = await file.read()
    try:
        return await service.enqueue_file_ingest(
            user_id=user.user_id,
            filename=file.filename,
            file_bytes=contents,
            source_type=SourceType.FILE,
            pdf_password=password,
        )
    except SpendSenseParseError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/staging", response_model=StagingRecord, summary="Stage raw transaction")
async def stage_transaction(
    record: StagingRecord,
    service: SpendSenseService = Depends(get_service),
) -> StagingRecord:
    return await service.stage_record(record)


@router.get("/kpis", response_model=SpendSenseKPI, summary="SpendSense KPI snapshot")
async def get_kpis(
    user: AuthenticatedUser = Depends(get_current_user),
    service: SpendSenseService = Depends(get_service),
) -> SpendSenseKPI:
    return await service.get_kpis(user.user_id)


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
    )
    return TransactionListResponse(
        transactions=transactions,
        total=total,
        limit=limit,
        offset=offset,
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
    try:
        return await service.update_transaction(
            user_id=user.user_id,
            txn_id=txn_id,
            category_code=update.category_code,
            subcategory_code=update.subcategory_code,
            txn_type=update.txn_type,
            merchant_name=update.merchant_name,
            channel=update.channel,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


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

