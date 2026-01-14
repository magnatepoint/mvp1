from datetime import date, datetime
from typing import Any
from pydantic import BaseModel, Field


class SourceType:
    MANUAL = "manual"
    EMAIL = "email"
    FILE = "file"


class StagingRecord(BaseModel):
    txn_id: str
    user_id: str
    txn_date: date
    description: str
    amount: float
    direction: str


class UploadBatchCreate(BaseModel):
    source_type: str
    account_ref: str | None = None


class UploadBatch(BaseModel):
    upload_id: str
    user_id: str
    source_type: str
    account_ref: str | None = None
    status: str
    created_at: datetime


class TransactionRecord(BaseModel):
    txn_id: str
    txn_date: date
    merchant: str | None
    category: str | None
    subcategory: str | None
    bank_code: str | None
    channel: str | None
    amount: float
    direction: str


class TransactionListResponse(BaseModel):
    transactions: list[TransactionRecord]
    total: int
    page: int
    page_size: int


class TransactionUpdate(BaseModel):
    category_code: str | None = None
    subcategory_code: str | None = None


class CategoryResponse(BaseModel):
    category_code: str
    category_name: str


class SubcategoryResponse(BaseModel):
    subcategory_code: str
    subcategory_name: str
    category_code: str


class CategorySpendKPI(BaseModel):
    category_code: str
    category_name: str
    txn_count: int
    spend_amount: float
    income_amount: float
    delta_pct: float | None = None


class WantsGauge(BaseModel):
    ratio: float
    label: str
    threshold_crossed: bool


class BestMonthSnapshot(BaseModel):
    month: date
    net_amount: float
    delta_pct: float | None
    is_current_best: bool


class LootDropSummary(BaseModel):
    batch_id: str
    occurred_at: datetime
    transactions_unlocked: int
    rarity: str = "common"


class AvailableMonthsResponse(BaseModel):
    data: list[str]


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


# Insights Models
class TimeSeriesPoint(BaseModel):
    date: str  # YYYY-MM-DD or YYYY-MM
    value: float
    label: str | None = None


class CategoryBreakdownItem(BaseModel):
    category_code: str
    category_name: str
    amount: float
    percentage: float
    transaction_count: int
    avg_transaction: float


class SpendingTrend(BaseModel):
    period: str  # YYYY-MM
    income: float
    expenses: float
    net: float
    needs: float
    wants: float
    assets: float


class RecurringTransaction(BaseModel):
    merchant_name: str
    category_code: str
    category_name: str
    subcategory_code: str | None
    subcategory_name: str | None
    frequency: str  # "monthly", "weekly", "daily", etc.
    avg_amount: float
    last_occurrence: date
    next_expected: date | None
    transaction_count: int
    total_amount: float


class SpendingPattern(BaseModel):
    day_of_week: str | None = None
    time_of_day: str | None = None
    amount: float
    transaction_count: int


class InsightsResponse(BaseModel):
    time_series: list[TimeSeriesPoint]
    category_breakdown: list[CategoryBreakdownItem]
    spending_trends: list[SpendingTrend]
    recurring_transactions: list[RecurringTransaction]
    spending_patterns: list[SpendingPattern]
    top_merchants: list[dict[str, Any]]
    anomalies: list[dict[str, Any]] | None = None
