from datetime import datetime, date
from enum import Enum
from typing import Any

from pydantic import BaseModel, Field


class SourceType(str, Enum):
    FILE = "file"
    EMAIL = "email"
    MANUAL = "manual"


class UploadBatch(BaseModel):
    batch_id: str = Field(..., description="UUID generated for the batch")
    user_id: str
    source_type: SourceType
    file_name: str | None = None
    total_rows: int = 0
    status: str = Field(default="pending")
    created_at: datetime = Field(default_factory=datetime.utcnow)


class UploadBatchCreate(BaseModel):
    source_type: SourceType
    file_name: str | None = None
    total_rows: int


class StagingRecord(BaseModel):
    user_id: str
    batch_id: str
    raw_payload: dict[str, Any]
    parsed_fields: dict[str, Any] | None = None
    source_type: SourceType
    created_at: datetime = Field(default_factory=datetime.utcnow)


class CategorySpendKPI(BaseModel):
    category_code: str
    category_name: str | None = None
    txn_count: int
    spend_amount: float
    income_amount: float
    share: float = Field(0.0, description="Share of total spend for the period (0-1)")
    tier: str = Field("bronze", description="Badge tier based on share (gold/silver/bronze/etc.)")
    change_pct: float | None = Field(
        default=None,
        description="Percent change vs previous month (positive = increase)",
    )


class WantsGauge(BaseModel):
    ratio: float = Field(0.0, description="Wants / (Needs + Wants)")
    label: str = Field(default="Chill Mode")
    threshold_crossed: bool = Field(default=False)


class BestMonthSnapshot(BaseModel):
    month: date
    income_amount: float
    needs_amount: float
    wants_amount: float
    delta_pct: float | None = Field(
        default=None,
        description="Percent difference between current month net and previous best",
    )
    is_current_best: bool = False


class LootDropSummary(BaseModel):
    batch_id: str
    file_name: str | None = None
    transactions_ingested: int = 0
    status: str = "received"
    occurred_at: datetime | None = None
    rarity: str = "common"


class SpendSenseKPI(BaseModel):
    month: date | None
    income_amount: float
    needs_amount: float
    wants_amount: float
    assets_amount: float
    top_categories: list[CategorySpendKPI]
    wants_gauge: WantsGauge | None = None
    best_month: BestMonthSnapshot | None = None
    recent_loot_drop: LootDropSummary | None = None


class SpendSenseActivity(BaseModel):
    timestamp: datetime
    title: str
    meta: str


class TransactionRecord(BaseModel):
    txn_id: str
    txn_date: datetime
    merchant: str | None = None
    category: str | None = None
    subcategory: str | None = None
    bank_code: str | None = None
    channel: str | None = None
    amount: float
    direction: str


class TransactionListResponse(BaseModel):
    transactions: list[TransactionRecord]
    total: int
    limit: int
    offset: int


class TransactionUpdate(BaseModel):
    category_code: str | None = None
    subcategory_code: str | None = None
    txn_type: str | None = None
    merchant_name: str | None = None
    channel: str | None = None


class CategoryResponse(BaseModel):
    code: str
    name: str
    is_custom: bool = False


class SubcategoryResponse(BaseModel):
    code: str
    name: str
    category_code: str | None = None
    is_custom: bool = False

