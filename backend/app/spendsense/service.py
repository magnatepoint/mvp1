from datetime import datetime, timedelta, date
from typing import List, Any

import base64
import logging

import asyncpg
from asyncpg import Pool

from app.core.config import get_settings
from .models import (
    SourceType,
    SpendSenseActivity,
    SpendSenseKPI,
    StagingRecord,
    TransactionRecord,
    TransactionCreate,
    UploadBatch,
    UploadBatchCreate,
    CategorySpendKPI,
    WantsGauge,
    BestMonthSnapshot,
    LootDropSummary,
)
from .etl.parsers import SpendSenseParseError
from .etl.tasks import ingest_statement_file_task
from .etl.pipeline import enrich_transactions
from .ml.predictor import get_predictor_service

logger = logging.getLogger(__name__)


class SpendSenseService:
    """Facade for SpendSense ingestion and KPI snapshots.

    The real implementation will talk to Supabase Postgres + Mongo, but we keep placeholders here
    so the API contract is testable while pipelines are under construction.
    """

    def __init__(self, pool: Pool) -> None:
        self._settings = get_settings()
        self._pool = pool

    async def create_upload_batch(self, user_id: str, payload: UploadBatchCreate) -> UploadBatch:
        # TODO: persist to Supabase/Postgres
        return UploadBatch(
            batch_id="mock-batch-id",
            user_id=user_id,
            source_type=payload.source_type,
            file_name=payload.file_name,
            total_rows=payload.total_rows,
            status="staging",
        )

    async def get_kpis(self, user_id: str, month: str | None = None) -> SpendSenseKPI:
        """Return dashboard KPIs from materialized views with graceful fallbacks.
        
        Args:
            user_id: User ID
            month: Optional month filter in YYYY-MM format (e.g., '2025-11'). 
                   If None, returns latest available month.
        """
        # First, check if user has any transactions at all
        # This prevents showing stale data from materialized views after deletion
        transaction_count = await self._pool.fetchval(
            """
            SELECT COUNT(*) FROM spendsense.txn_fact WHERE user_id = $1
            """,
            user_id,
        )
        
        # If no transactions exist, return zeros immediately
        if transaction_count == 0:
            return SpendSenseKPI(
                month=None,
                income_amount=0.0,
                needs_amount=0.0,
                wants_amount=0.0,
                assets_amount=0.0,
                top_categories=[],
                wants_gauge=self._build_wants_gauge(0.0, 0.0),
                best_month=None,
                recent_loot_drop=None,
            )
        
        # Parse month filter if provided
        target_month = None
        if month:
            try:
                # Validate and parse YYYY-MM format
                from datetime import datetime
                target_month = datetime.strptime(month, "%Y-%m").date().replace(day=1)
            except ValueError:
                # Invalid format, ignore and use latest
                pass
        
        # Always use fallback calculation to ensure transaction overrides are respected
        # Materialized views don't include overrides, so we calculate directly from source tables
        # This ensures KPIs reflect user edits immediately without needing to refresh MVs
        try:
            return await self._compute_kpis_fallback(user_id, target_month)
        except Exception as exc:
            logger.error("Failed to compute KPIs: %s", exc, exc_info=True)
            return SpendSenseKPI(
                month=None,
                income_amount=0.0,
                needs_amount=0.0,
                wants_amount=0.0,
                assets_amount=0.0,
                top_categories=[],
                wants_gauge=self._build_wants_gauge(0.0, 0.0),
                best_month=None,
                recent_loot_drop=None,
            )

    async def _compute_kpis_fallback(self, user_id: str, target_month: date | None = None) -> SpendSenseKPI:
        """Compute KPIs directly from txn_fact when MVs aren't available.
        
        Args:
            user_id: User ID
            target_month: Optional target month. If None, uses latest available month.
        """
        from datetime import date
        
        # Determine which month to use
        if target_month:
            latest_month = target_month
        else:
            # Get the latest month with transactions
            latest_month_row = await self._pool.fetchrow(
                """
                SELECT DATE_TRUNC('month', MAX(txn_date))::date AS latest_month
                FROM spendsense.txn_fact
                WHERE user_id = $1
                """,
                user_id,
            )
            
            if not latest_month_row or not latest_month_row["latest_month"]:
                # No transactions at all
                return SpendSenseKPI(
                    month=None,
                    income_amount=0.0,
                    needs_amount=0.0,
                    wants_amount=0.0,
                    assets_amount=0.0,
                    top_categories=[],
                    wants_gauge=self._build_wants_gauge(0.0, 0.0),
                    best_month=None,
                    recent_loot_drop=None,
                )
            
            latest_month = latest_month_row["latest_month"]
        
        row = await self._pool.fetchrow(
            """
            WITH enriched AS (
                SELECT
                    f.txn_date,
                    f.amount,
                    f.direction,
                    -- Use override if exists, otherwise use enriched category
                    COALESCE(
                        ov.category_code,
                        e.category_id,
                        'uncategorized'
                    ) AS category_code,
                    -- Use override txn_type if exists, otherwise derive from category
                    COALESCE(
                        ov.txn_type,
                        dc.txn_type,
                        CASE 
                            WHEN f.direction = 'credit' THEN 'income'
                            ELSE 'needs'
                        END
                    ) AS txn_type
                FROM spendsense.txn_fact f
                LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
                LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
                LEFT JOIN spendsense.dim_category dc ON dc.category_code = COALESCE(
                    (SELECT category_code FROM spendsense.txn_override WHERE txn_id = f.txn_id ORDER BY created_at DESC LIMIT 1),
                    e.category_id
                )
                LEFT JOIN LATERAL (
                    SELECT category_code, txn_type
                    FROM spendsense.txn_override
                    WHERE txn_id = f.txn_id
                    ORDER BY created_at DESC
                    LIMIT 1
                ) ov ON TRUE
                WHERE f.user_id = $1
                  AND f.txn_date >= $2
                  AND f.txn_date < ($2 + INTERVAL '1 month')::date
            )
            SELECT
                $2::date AS month,
                COALESCE(SUM(CASE WHEN direction = 'credit' THEN amount ELSE 0 END), 0) AS income_amount,
                COALESCE(SUM(CASE WHEN txn_type = 'needs' THEN amount ELSE 0 END), 0) AS needs_amount,
                COALESCE(SUM(CASE WHEN txn_type = 'wants' THEN amount ELSE 0 END), 0) AS wants_amount,
                COALESCE(SUM(CASE WHEN txn_type = 'assets' THEN amount ELSE 0 END), 0) AS assets_amount
            FROM enriched
            """,
            user_id,
            latest_month,
        )

        month: date | None = row["month"] if row else None

        categories = await self._pool.fetch(
            """
            SELECT
                -- Use override if exists, otherwise use enriched category
                COALESCE(
                    ov.category_code,
                    e.category_id,
                    'uncategorized'
                ) AS category_code,
                COALESCE(
                    dc_override.category_name,
                    dc.category_name,
                    ov.category_code,
                    e.category_id,
                    'Uncategorized'
                ) AS category_name,
                COUNT(*) AS txn_count,
                SUM(CASE WHEN f.direction = 'debit' THEN f.amount ELSE 0 END) AS spend_amount,
                SUM(CASE WHEN f.direction = 'credit' THEN f.amount ELSE 0 END) AS income_amount
            FROM spendsense.txn_fact f
            LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
            LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
            LEFT JOIN LATERAL (
                SELECT category_code, subcategory_code, txn_type
                FROM spendsense.txn_override
                WHERE txn_id = f.txn_id
                ORDER BY created_at DESC
                LIMIT 1
            ) ov ON TRUE
            LEFT JOIN spendsense.dim_category dc ON dc.category_code = e.category_id
            LEFT JOIN spendsense.dim_category dc_override ON dc_override.category_code = ov.category_code
            WHERE f.user_id = $1
              AND f.txn_date >= $2
              AND f.txn_date < ($2 + INTERVAL '1 month')::date
            GROUP BY 
                COALESCE(ov.category_code, e.category_id, 'uncategorized'),
                COALESCE(dc_override.category_name, dc.category_name, ov.category_code, e.category_id, 'Uncategorized')
            ORDER BY spend_amount DESC NULLS LAST
            LIMIT 5
            """,
            user_id,
            latest_month,
        )

        # Get previous month for comparison
        prev_month = latest_month - timedelta(days=32)  # Go back ~1 month, then truncate
        prev_month = prev_month.replace(day=1)
        
        prev_categories_rows = await self._pool.fetch(
            """
            SELECT
                -- Use override if exists, otherwise use enriched category
                COALESCE(
                    ov.category_code,
                    e.category_id,
                    'uncategorized'
                ) AS category_code,
                SUM(CASE WHEN f.direction = 'debit' THEN f.amount ELSE 0 END) AS spend_amount
            FROM spendsense.txn_fact f
            LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
            LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
            LEFT JOIN LATERAL (
                SELECT category_code
                FROM spendsense.txn_override
                WHERE txn_id = f.txn_id
                ORDER BY created_at DESC
                LIMIT 1
            ) ov ON TRUE
            WHERE f.user_id = $1
              AND f.txn_date >= $2
              AND f.txn_date < ($2 + INTERVAL '1 month')::date
            GROUP BY COALESCE(ov.category_code, e.category_id, 'uncategorized')
            """,
            user_id,
            prev_month,
        )

        prev_map = {row["category_code"]: float(row["spend_amount"] or 0) for row in prev_categories_rows}
        top_categories = self._build_category_badges(categories, prev_map)

        wants_amount = float(row["wants_amount"] or 0) if row else 0.0
        needs_amount = float(row["needs_amount"] or 0) if row else 0.0
        wants_gauge = self._build_wants_gauge(needs=needs_amount, wants=wants_amount)

        best_month = await self._fetch_best_month_from_fact(
            user_id=user_id,
            current_month=month,
            current_net=(float(row["income_amount"] or 0) - wants_amount) if row else 0.0,
        )

        loot_drop = await self._fetch_recent_loot_drop(user_id)

        return SpendSenseKPI(
            month=month,
            income_amount=float(row["income_amount"] or 0) if row else 0.0,
            needs_amount=needs_amount,
            wants_amount=wants_amount,
            assets_amount=float(row["assets_amount"] or 0) if row else 0.0,
            top_categories=top_categories,
            wants_gauge=wants_gauge,
            best_month=best_month,
            recent_loot_drop=loot_drop,
        )

    async def _fetch_prev_month_category_spend(self, user_id: str, current_month: date | None) -> dict[str, float]:
        if not current_month:
            return {}
        # Calculate previous month
        prev_month = current_month - timedelta(days=32)
        prev_month = prev_month.replace(day=1)
        
        # Query with overrides support
        rows = await self._pool.fetch(
            """
            SELECT
                -- Use override if exists, otherwise use enriched category
                COALESCE(
                    ov.category_code,
                    e.category_id,
                    'uncategorized'
                ) AS category_code,
                SUM(CASE WHEN f.direction = 'debit' THEN f.amount ELSE 0 END) AS spend_amount
            FROM spendsense.txn_fact f
            LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
            LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
            LEFT JOIN LATERAL (
                SELECT category_code
                FROM spendsense.txn_override
                WHERE txn_id = f.txn_id
                ORDER BY created_at DESC
                LIMIT 1
            ) ov ON TRUE
            WHERE f.user_id = $1
              AND f.txn_date >= $2
              AND f.txn_date < ($2 + INTERVAL '1 month')::date
            GROUP BY COALESCE(ov.category_code, e.category_id, 'uncategorized')
            """,
            user_id,
            prev_month,
        )
        return {row["category_code"]: float(row["spend_amount"] or 0) for row in rows}

    def _build_category_badges(
        self,
        rows: list[asyncpg.Record],
        prev_month_map: dict[str, float],
    ) -> list[CategorySpendKPI]:
        total_spend = sum(max(0.0, float(r["spend_amount"] or 0)) for r in rows)
        badges: list[CategorySpendKPI] = []
        for record in rows:
            spend_amount = float(record["spend_amount"] or 0)
            prev_amount = prev_month_map.get(record["category_code"], 0.0)
            if prev_amount > 0:
                change_pct = ((spend_amount - prev_amount) / prev_amount) * 100.0
            elif spend_amount > 0:
                change_pct = 100.0
            else:
                change_pct = None
            share = (spend_amount / total_spend) if total_spend else 0.0
            badges.append(
                CategorySpendKPI(
                    category_code=record["category_code"],
                    category_name=record["category_name"],
                    txn_count=record["txn_count"],
                    spend_amount=spend_amount,
                    income_amount=float(record["income_amount"] or 0),
                    share=share,
                    tier=self._tier_from_share(share),
                    change_pct=change_pct,
                )
            )
        return badges

    @staticmethod
    def _tier_from_share(share: float) -> str:
        if share >= 0.4:
            return "gold"
        if share >= 0.25:
            return "silver"
        if share >= 0.12:
            return "bronze"
        return "ember"

    @staticmethod
    def _build_wants_gauge(needs: float, wants: float) -> WantsGauge:
        total = max(needs + wants, 0.0)
        ratio = wants / total if total else 0.0
        if ratio <= 0.4:
            label = "Chill Mode"
            threshold = False
        elif ratio <= 0.6:
            label = "Balanced"
            threshold = False
        else:
            label = "Caution Zone"
            threshold = True
        return WantsGauge(ratio=ratio, label=label, threshold_crossed=threshold)

    async def _fetch_best_month_from_mv(
        self,
        user_id: str,
        current_month: date | None,
        current_net: float,
    ) -> BestMonthSnapshot | None:
        best_row = await self._pool.fetchrow(
            """
            SELECT month, income_amt, needs_amt, wants_amt
            FROM spendsense.mv_spendsense_dashboard_user_month
            WHERE user_id = $1
            ORDER BY (income_amt - wants_amt) DESC, month DESC
            LIMIT 1
            """,
            user_id,
        )
        prev_best_row = None
        if best_row and current_month and best_row["month"] == current_month:
            prev_best_row = await self._pool.fetchrow(
                """
                SELECT month, income_amt, needs_amt, wants_amt
                FROM spendsense.mv_spendsense_dashboard_user_month
                WHERE user_id = $1 AND month <> $2
                ORDER BY (income_amt - wants_amt) DESC, month DESC
                LIMIT 1
                """,
                user_id,
                current_month,
            )
        return self._build_best_month_snapshot(best_row, prev_best_row, current_month, current_net)

    async def _fetch_best_month_from_fact(
        self,
        user_id: str,
        current_month: date | None,
        current_net: float,
    ) -> BestMonthSnapshot | None:
        best_row = await self._pool.fetchrow(
            """
            SELECT month,
                   income_amount,
                   needs_amount,
                   wants_amount
            FROM (
                SELECT DATE_TRUNC('month', f.txn_date)::date AS month,
                       SUM(CASE WHEN f.direction = 'credit' THEN f.amount ELSE 0 END) AS income_amount,
                       SUM(CASE WHEN COALESCE(dc.txn_type, 'needs') = 'needs' THEN f.amount ELSE 0 END) AS needs_amount,
                       SUM(CASE WHEN COALESCE(dc.txn_type, 'needs') = 'wants' THEN f.amount ELSE 0 END) AS wants_amount
                FROM spendsense.txn_fact f
                LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
                LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
                LEFT JOIN spendsense.dim_category dc ON dc.category_code = e.category_id
                WHERE f.user_id = $1
                GROUP BY 1
            ) stats
            ORDER BY (income_amount - wants_amount) DESC, month DESC
            LIMIT 1
            """,
            user_id,
        )
        prev_best_row = None
        if best_row and current_month and best_row["month"] == current_month:
            prev_best_row = await self._pool.fetchrow(
                """
                SELECT month,
                       income_amount,
                       needs_amount,
                       wants_amount
                FROM (
                    SELECT DATE_TRUNC('month', f.txn_date)::date AS month,
                           SUM(CASE WHEN f.direction = 'credit' THEN f.amount ELSE 0 END) AS income_amount,
                           SUM(CASE WHEN COALESCE(dc.txn_type, 'needs') = 'needs' THEN f.amount ELSE 0 END) AS needs_amount,
                           SUM(CASE WHEN COALESCE(dc.txn_type, 'needs') = 'wants' THEN f.amount ELSE 0 END) AS wants_amount
                    FROM spendsense.txn_fact f
                    LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
                    LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
                    LEFT JOIN spendsense.dim_category dc ON dc.category_code = e.category_id
                    WHERE f.user_id = $1
                    GROUP BY 1
                ) stats
                WHERE month <> $2
                ORDER BY (income_amount - wants_amount) DESC, month DESC
                LIMIT 1
                """,
                user_id,
                current_month,
            )
        return self._build_best_month_snapshot(best_row, prev_best_row, current_month, current_net)

    def _build_best_month_snapshot(
        self,
        best_row: asyncpg.Record | None,
        prev_best_row: asyncpg.Record | None,
        current_month: date | None,
        current_net: float,
    ) -> BestMonthSnapshot | None:
        if not best_row:
            return None
        best_row_dict = dict(best_row)
        income_key = "income_amt" if "income_amt" in best_row_dict else "income_amount"
        wants_key = "wants_amt" if "wants_amt" in best_row_dict else "wants_amount"
        needs_key = "needs_amt" if "needs_amt" in best_row_dict else "needs_amount"
        best_net = float(best_row_dict.get(income_key, 0) or 0) - float(best_row_dict.get(wants_key, 0) or 0)

        is_current_best = current_month is not None and best_row["month"] == current_month
        baseline_row = prev_best_row if is_current_best else None
        delta_pct = None
        if is_current_best and baseline_row:
            prev_dict = dict(baseline_row)
            baseline_income = float(prev_dict.get("income_amt", prev_dict.get("income_amount", 0)) or 0)
            baseline_wants = float(prev_dict.get("wants_amt", prev_dict.get("wants_amount", 0)) or 0)
            delta_pct = self._compute_delta_pct(current_net, baseline_income - baseline_wants)
        elif not is_current_best:
            delta_pct = self._compute_delta_pct(current_net, best_net)

        return BestMonthSnapshot(
            month=best_row["month"],
            net_amount=best_net,
            delta_pct=delta_pct,
            is_current_best=is_current_best,
        )

    @staticmethod
    def _compute_delta_pct(current_value: float, baseline: float) -> float | None:
        if baseline == 0:
            return None if current_value == 0 else 100.0
        return ((current_value - baseline) / abs(baseline)) * 100.0

    async def _fetch_recent_loot_drop(self, user_id: str) -> LootDropSummary | None:
        row = await self._pool.fetchrow(
            """
            SELECT upload_id,
                   file_name,
                   parsed_records,
                   total_records,
                   status,
                   received_at
            FROM spendsense.upload_batch
            WHERE user_id = $1
            ORDER BY received_at DESC
            LIMIT 1
            """,
            user_id,
        )
        if not row:
            return None
        parsed = int(row["parsed_records"] or 0)
        total = int(row["total_records"] or 0)
        transactions = parsed or total
        return LootDropSummary(
            batch_id=str(row["upload_id"]),
            occurred_at=row["received_at"],
            transactions_unlocked=transactions,
            rarity=self._rarity_from_records(transactions),
        )

    @staticmethod
    def _rarity_from_records(transactions: int) -> str:
        if transactions >= 200:
            return "legendary"
        if transactions >= 100:
            return "epic"
        if transactions >= 40:
            return "rare"
        return "common"

    async def list_activity(self, user_id: str) -> List[SpendSenseActivity]:
        now = datetime.utcnow()
        return [
            SpendSenseActivity(
                timestamp=now - timedelta(minutes=15),
                title="SpendSense ingest completed",
                meta="Gmail parser · 4.3k events",
            ),
            SpendSenseActivity(
                timestamp=now - timedelta(hours=1),
                title="GoalCompass priority reshuffle",
                meta="Top 3 goals recalculated",
            ),
        ]

    async def stage_record(self, record: StagingRecord) -> StagingRecord:
        # TODO: push into Mongo staging collection
        return record

    async def enqueue_file_ingest(
        self,
        user_id: str,
        filename: str,
        file_bytes: bytes,
        source_type: str = SourceType.FILE,
        pdf_password: str | None = None,
    ) -> UploadBatch:
        if not filename:
            raise SpendSenseParseError("Filename is required")

        file_size = len(file_bytes)
        logger.info(f"Enqueueing file ingest: user_id={user_id}, filename={filename}, size={file_size} bytes, has_password={bool(pdf_password)}")

        async with self._pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                INSERT INTO spendsense.upload_batch (user_id, source_type, file_name, status)
                VALUES ($1, $2, $3, 'received')
                RETURNING upload_id, user_id, source_type, status, received_at
                """,
                user_id,
                source_type,  # SourceType is already a string, not an enum
                filename,
            )

        batch_id = str(row["upload_id"])
        logger.info(f"Upload batch created: batch_id={batch_id}, enqueueing Celery task...")

        try:
            # Encode file to base64 for Celery task
            file_b64 = base64.b64encode(file_bytes).decode("ascii")
            logger.info(f"File encoded to base64: {len(file_b64)} characters")
            
            # Enqueue Celery task
            task_result = ingest_statement_file_task.delay(
                batch_id=batch_id,
                user_id=user_id,
                filename=filename,
                file_b64=file_b64,
                pdf_password=pdf_password,
            )
            logger.info(f"Celery task enqueued successfully: task_id={task_result.id}, batch_id={batch_id}")
        except Exception as exc:
            logger.error(f"Failed to enqueue Celery task for batch {batch_id}: {exc}", exc_info=True)
            # Update batch status to failed
            async with self._pool.acquire() as conn:
                await conn.execute(
                    "UPDATE spendsense.upload_batch SET status = 'failed' WHERE upload_id = $1",
                    batch_id,
                )
            raise SpendSenseParseError(f"Failed to enqueue file processing: {str(exc)}") from exc

        return UploadBatch(
            upload_id=batch_id,
            user_id=str(row["user_id"]),
            source_type=str(row["source_type"]),
            status=str(row["status"]),
            created_at=row["received_at"],  # Map received_at to created_at for the model
        )

    async def get_batch_status(self, batch_id: str, user_id: str) -> UploadBatch | None:
        """Get the current status of an upload batch."""
        query = """
        SELECT upload_id, user_id, source_type, status, received_at
        FROM spendsense.upload_batch
        WHERE upload_id = $1 AND user_id = $2
        """
        row = await self._pool.fetchrow(query, batch_id, user_id)
        if not row:
            return None
        return UploadBatch(
            upload_id=str(row["upload_id"]),
            user_id=str(row["user_id"]),
            source_type=str(row["source_type"]),  # source_type is already a string from DB
            status=str(row["status"]),
            created_at=row["received_at"],  # Map received_at to created_at for the model
        )

    async def list_transactions(
        self,
        user_id: str,
        limit: int,
        offset: int,
        search: str | None = None,
        category_code: str | None = None,
        subcategory_code: str | None = None,
        channel: str | None = None,
        start_date: str | None = None,
        end_date: str | None = None,
        **kwargs: Any,
    ) -> tuple[List[TransactionRecord], int]:
        """List transactions with pagination and optional filters."""
        where_clauses = ["v.user_id = $1"]
        params: list[Any] = [user_id]
        placeholder = 2

        def add_clause(clause: str, value: Any) -> None:
            nonlocal placeholder
            where_clauses.append(clause.format(idx=placeholder))
            params.append(value)
            placeholder += 1

        if start_date:
            try:
                s_date = datetime.strptime(start_date, "%Y-%m-%d").date()
                add_clause("v.txn_date >= ${idx}", s_date)
            except ValueError:
                pass  # Ignore invalid dates

        if end_date:
            try:
                e_date = datetime.strptime(end_date, "%Y-%m-%d").date()
                add_clause("v.txn_date <= ${idx}", e_date)
            except ValueError:
                pass  # Ignore invalid dates

        if search:
            search_value = f"%{search.strip()}%"
            add_clause(
                "(COALESCE(v.merchant_name_norm, '') ILIKE ${idx} OR COALESCE(v.description, '') ILIKE ${idx})",
                search_value,
            )

        if category_code:
            add_clause("v.category_code = ${idx}", category_code)

        if subcategory_code:
            add_clause("v.subcategory_code = ${idx}", subcategory_code)

        if channel:
            add_clause("LOWER(v.channel) = LOWER(${idx})", channel)

        if kwargs.get("direction"):
            direction_value = kwargs["direction"]
            if direction_value in ("debit", "credit"):
                add_clause("v.direction = ${idx}", direction_value)

        where_sql = " AND ".join(where_clauses)

        count_query = f"""
        SELECT COUNT(*) as total
        FROM spendsense.vw_txn_effective v
        WHERE {where_sql}
        """
        total_count = await self._pool.fetchval(count_query, *params) or 0

        query = f"""
        SELECT
            v.txn_id,
            v.txn_date,
            COALESCE(
                v.merchant_name_norm,
                -- Extract merchant from description if merchant_name_norm is NULL
                CASE 
                    WHEN v.description ~* '^TO TRANSFER-UPI/DR/[^/]+/([^/]+)/' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^TO TRANSFER-UPI/DR/[^/]+/([^/]+)/'))[1],
                            '\\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '^UPI-([^-]+)-' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^UPI-([^-]+)-'))[1],
                            '\\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* 'UPI/([^/]+)/' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, 'UPI/([^/]+)/'))[1],
                            '\\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '^IMPS-[^-]+-([^-]+)-' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^IMPS-[^-]+-([^-]+)-'))[1],
                            '\\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '(NEFT|NEFT)[-/]([^-/\\s]+)' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '(NEFT|NEFT)[-/]([^-/\\s]+)'))[2],
                            '\\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '^ACH\\s+([^-/]+)' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^ACH\s+([^-/]+)'))[1],
                            '\\s+', ' ', 'g'
                        ))
                    -- For simple descriptions, use the description itself (limited length)
                    WHEN v.description IS NOT NULL 
                         AND LENGTH(TRIM(v.description)) > 0 
                         AND LENGTH(TRIM(v.description)) <= 50
                         AND LOWER(TRIM(v.description)) NOT IN ('test transaction - today', 'salary', 'payment', 'transfer', 'debit', 'credit')
                         AND v.description !~* '^\d+$'
                    THEN INITCAP(REGEXP_REPLACE(TRIM(v.description), '\\s+', ' ', 'g'))
                    -- Fallback to bank name if description is empty
                    WHEN v.bank_code IS NOT NULL THEN
                        INITCAP(REPLACE(v.bank_code, '_', ' '))
                    ELSE 'Unknown'
                END
            ) AS merchant_name,
            COALESCE(dc.category_name, v.category_code) AS category_name,
            COALESCE(ds.subcategory_name, v.subcategory_code) AS subcategory_name,
            v.bank_code,
            v.channel,
            v.amount,
            v.direction
        FROM spendsense.vw_txn_effective v
        LEFT JOIN spendsense.dim_category dc ON dc.category_code = v.category_code
        LEFT JOIN spendsense.dim_subcategory ds ON ds.subcategory_code = v.subcategory_code
        WHERE {where_sql}
        ORDER BY v.txn_date DESC
        LIMIT ${placeholder} OFFSET ${placeholder + 1};
        """

        records = await self._pool.fetch(query, *params, limit, offset)
        return (
            [
                TransactionRecord(
                    txn_id=str(row["txn_id"]),
                    txn_date=row["txn_date"],
                    merchant=row["merchant_name"],
                    category=row["category_name"],
                    subcategory=row["subcategory_name"],
                    bank_code=row["bank_code"],
                    channel=row["channel"],
                    amount=row["amount"],
                    direction=row["direction"],
                )
                for row in records
            ],
            total_count,
        )

    async def delete_all_user_data(self, user_id: str) -> dict[str, int]:
        """Delete all transaction data for a user. Returns counts of deleted records."""
        # Delete in order to respect foreign key constraints
        # 1. Delete overrides (references txn_fact)
        override_result = await self._pool.execute(
            """
            DELETE FROM spendsense.txn_override
            WHERE user_id = $1
            """,
            user_id,
        )
        override_count = int(override_result.split()[-1]) if override_result else 0
        
        # 2. Delete enriched records (references txn_fact via txn_id)
        # This will be handled by CASCADE when we delete txn_fact
        
        # 3. Delete fact records (this will CASCADE to enriched)
        fact_result = await self._pool.execute(
            """
            DELETE FROM spendsense.txn_fact
            WHERE user_id = $1
            """,
            user_id,
        )
        fact_count = int(fact_result.split()[-1]) if fact_result else 0
        
        # 4. Delete staging records (check both schemas for compatibility)
        staging_result = await self._pool.execute(
            """
            DELETE FROM spendsense.txn_staging
            WHERE user_id = $1
            """,
            user_id,
        )
        staging_count = int(staging_result.split()[-1]) if staging_result else 0
        
        # 5. Delete upload batches
        batch_result = await self._pool.execute(
            """
            DELETE FROM spendsense.upload_batch
            WHERE user_id = $1
            """,
            user_id,
        )
        batch_count = int(batch_result.split()[-1]) if batch_result else 0
        
        return {
            "batches_deleted": batch_count,
            "staging_deleted": staging_count,
            "transactions_deleted": fact_count,
            "overrides_deleted": override_count,
        }

    async def update_transaction(
        self,
        user_id: str,
        txn_id: str,
        category_code: str | None = None,
        subcategory_code: str | None = None,
        txn_type: str | None = None,
        merchant_name: str | None = None,
        channel: str | None = None,
    ) -> TransactionRecord:
        """Update transaction category/subcategory via override."""
        logger.info(
            f"update_transaction called: txn_id={txn_id}, user_id={user_id}, "
            f"category_code={category_code}, subcategory_code={subcategory_code}, "
            f"txn_type={txn_type}, merchant_name={merchant_name}, channel={channel}"
        )
        
        # Get original transaction and enriched data for feedback
        original_query = """
        SELECT 
            f.txn_id,
            f.merchant_name_norm,
            f.description,
            f.amount,
            f.direction,
            e.category_id AS original_category,
            e.subcategory_id AS original_subcategory
        FROM spendsense.txn_fact f
        LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
        LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
        WHERE f.txn_id = $1 AND f.user_id = $2
        """
        original = await self._pool.fetchrow(original_query, txn_id, user_id)
        if not original:
            logger.warning(f"Transaction not found: txn_id={txn_id}, user_id={user_id}")
            raise ValueError("Transaction not found or access denied")
        
        logger.info(
            f"Original transaction: category={original.get('original_category')}, "
            f"subcategory={original.get('original_subcategory')}"
        )
        
        sanitized_merchant = None
        if merchant_name is not None:
            sanitized_merchant = merchant_name.strip() or None
        
        sanitized_channel = None
        if channel is not None:
            sanitized_channel = channel.strip() or None
            if sanitized_channel:
                sanitized_channel = sanitized_channel.lower()

        merchant_changed = sanitized_merchant is not None and sanitized_merchant != (original.get("merchant_name_norm") or "")
        channel_changed = sanitized_channel is not None and sanitized_channel != (original.get("channel") or "")

        if (merchant_changed or channel_changed) and original.get("merchant_name_norm"):
            await self._pool.execute(
                """
                INSERT INTO spendsense.ml_merchant_feedback (
                    txn_id,
                    user_id,
                    original_merchant,
                    corrected_merchant,
                    original_channel,
                    corrected_channel,
                    merchant_hash
                )
                VALUES (
                    $1,
                    $2,
                    $3,
                    $4,
                    $5,
                    $6,
                    md5(COALESCE(lower(trim($3)), ''))
                )
                """,
                txn_id,
                user_id,
                original.get("merchant_name_norm"),
                sanitized_merchant if merchant_changed else original.get("merchant_name_norm"),
                original.get("channel"),
                sanitized_channel if channel_changed else original.get("channel"),
            )
            from .ml.tasks import apply_merchant_feedback_task

            apply_merchant_feedback_task.delay()
        
        # Record feedback if category/subcategory changed
        if category_code and category_code != original.get("original_category"):
            conn = await self._pool.acquire()
            try:
                # Learn from edit: create merchant rule for future transactions
                from .services.learning_service import learn_from_edit
                
                merchant_name = original.get("merchant_name_norm") or ""
                description = original.get("description") or ""
                
                if merchant_name:
                    rule_id = await learn_from_edit(
                        conn,
                        user_id,
                        merchant_name,
                        description,
                        category_code,
                        subcategory_code,
                        txn_id,
                    )
                    if rule_id:
                        logger.info(
                            f"Created merchant rule from user edit: {merchant_name} → "
                            f"{category_code}/{subcategory_code} (rule_id: {rule_id})"
                        )
                
                # Also record feedback for ML training
                predictor_service = get_predictor_service()
                await predictor_service.record_feedback(
                    conn,
                    txn_id,
                    user_id,
                    original.get("original_category"),
                    original.get("original_subcategory"),
                    category_code,
                    subcategory_code,
                    merchant_name,
                    description,
                    float(original.get("amount", 0)),
                    original.get("direction"),
                )
                # Trigger async retraining if enough feedback accumulated
                from .ml.tasks import retrain_user_model_task
                retrain_user_model_task.delay(user_id)
            finally:
                await self._pool.release(conn)

        # Delete existing override if any, then insert new one
        # (Since there's no unique constraint, we delete first to avoid duplicates)
        delete_query = """
        DELETE FROM spendsense.txn_override
        WHERE txn_id = $1 AND user_id = $2
        """
        await self._pool.execute(delete_query, txn_id, user_id)
        
        # Only insert override if at least one of category_code, subcategory_code, or txn_type is provided
        # If all are None, there's nothing to override
        if category_code is not None or subcategory_code is not None or txn_type is not None:
            override_query = """
            INSERT INTO spendsense.txn_override (
                txn_id, user_id, category_code, subcategory_code, txn_type
            )
            VALUES ($1, $2, $3, $4, $5)
            """
            await self._pool.execute(
                override_query,
                txn_id,
                user_id,
                category_code,
                subcategory_code,
                txn_type,
            )
            logger.info(
                f"Created transaction override: txn_id={txn_id}, user_id={user_id}, "
                f"category={category_code}, subcategory={subcategory_code}, txn_type={txn_type}"
            )
        else:
            logger.debug(
                f"No override created for txn_id={txn_id}: all category fields are None"
            )

        update_params = [txn_id, user_id]
        update_clauses: list[str] = []
        if sanitized_merchant is not None:
            update_clauses.append(f"merchant_name_norm = ${len(update_params)+1}")
            update_params.append(sanitized_merchant)
        if sanitized_channel is not None:
            update_clauses.append(f"channel = ${len(update_params)+1}")
            update_params.append(sanitized_channel)
        
        if update_clauses:
            update_query = f"""
            UPDATE spendsense.txn_fact
            SET {", ".join(update_clauses)}
            WHERE txn_id = $1 AND user_id = $2
            """
            await self._pool.execute(update_query, *update_params)

        # Return updated transaction from effective view
        query = """
        SELECT
            v.txn_id,
            v.txn_date,
            COALESCE(
                v.merchant_name_norm,
                -- Extract merchant from description if merchant_name_norm is NULL
                CASE 
                    WHEN v.description ~* '^TO TRANSFER-UPI/DR/[^/]+/([^/]+)/' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^TO TRANSFER-UPI/DR/[^/]+/([^/]+)/'))[1],
                            '\\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '^UPI-([^-]+)-' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^UPI-([^-]+)-'))[1],
                            '\\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* 'UPI/([^/]+)/' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, 'UPI/([^/]+)/'))[1],
                            '\\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '^IMPS-[^-]+-([^-]+)-' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^IMPS-[^-]+-([^-]+)-'))[1],
                            '\\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '(NEFT|NEFT)[-/]([^-/\\s]+)' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '(NEFT|NEFT)[-/]([^-/\\s]+)'))[2],
                            '\\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '^ACH\\s+([^-/]+)' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^ACH\s+([^-/]+)'))[1],
                            '\\s+', ' ', 'g'
                        ))
                    -- For simple descriptions, use the description itself (limited length)
                    WHEN v.description IS NOT NULL 
                         AND LENGTH(TRIM(v.description)) > 0 
                         AND LENGTH(TRIM(v.description)) <= 50
                         AND LOWER(TRIM(v.description)) NOT IN ('test transaction - today', 'salary', 'payment', 'transfer', 'debit', 'credit')
                         AND v.description !~* '^\d+$'
                    THEN INITCAP(REGEXP_REPLACE(TRIM(v.description), '\\s+', ' ', 'g'))
                    -- Fallback to bank name if description is empty
                    WHEN v.bank_code IS NOT NULL THEN
                        INITCAP(REPLACE(v.bank_code, '_', ' '))
                    ELSE 'Unknown'
                END
            ) AS merchant_name,
            COALESCE(dc.category_name, v.category_code) AS category_name,
            COALESCE(ds.subcategory_name, v.subcategory_code) AS subcategory_name,
            v.bank_code,
            v.channel,
            v.amount,
            v.direction
        FROM spendsense.vw_txn_effective v
        LEFT JOIN spendsense.dim_category dc ON dc.category_code = v.category_code
        LEFT JOIN spendsense.dim_subcategory ds ON ds.subcategory_code = v.subcategory_code
        WHERE v.txn_id = $1 AND v.user_id = $2
        """
        row = await self._pool.fetchrow(query, txn_id, user_id)
        if not row:
            raise ValueError("Transaction not found after update")

        return TransactionRecord(
            txn_id=str(row["txn_id"]),
            txn_date=row["txn_date"],
            merchant=row["merchant_name"],
            category=row["category_name"],
            subcategory=row["subcategory_name"],
            bank_code=row["bank_code"],
            channel=row["channel"],
            amount=row["amount"],
            direction=row["direction"],
        )

    async def create_manual_transaction(
        self,
        user_id: str,
        data: TransactionCreate,
    ) -> TransactionRecord:
        """Create a manual transaction."""
        import uuid
        from datetime import datetime
        
        # Validate direction
        if data.direction not in ('debit', 'credit'):
            raise ValueError("direction must be 'debit' or 'credit'")
        
        # Validate amount is positive
        if data.amount <= 0:
            raise ValueError("amount must be positive")
        
        # Create upload batch for manual transaction
        batch_row = await self._pool.fetchrow(
            """
            INSERT INTO spendsense.upload_batch (user_id, source_type, status)
            VALUES ($1, $2, 'completed')
            RETURNING upload_id
            """,
            user_id,
            SourceType.MANUAL,
        )
        upload_id = batch_row["upload_id"]
        
        # Normalize merchant name
        merchant_normalized = data.merchant_name.strip().lower() if data.merchant_name else None
        
        # Insert into txn_fact
        txn_id = uuid.uuid4()
        await self._pool.execute(
            """
            INSERT INTO spendsense.txn_fact (
                txn_id, user_id, upload_id, source_type,
                txn_date, description, amount, direction, currency,
                merchant_name_norm, account_ref
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            """,
            txn_id,
            user_id,
            upload_id,
            SourceType.MANUAL,
            data.txn_date,
            data.description,
            data.amount,
            data.direction,
            'INR',
            merchant_normalized,
            data.account_ref,
        )
        
        # If category/subcategory provided, create override
        if data.category_code or data.subcategory_code:
            # Determine txn_type from category if category_code provided
            txn_type = None
            if data.category_code:
                category_row = await self._pool.fetchrow(
                    "SELECT txn_type FROM spendsense.dim_category WHERE category_code = $1",
                    data.category_code,
                )
                if category_row:
                    txn_type = category_row["txn_type"]
            
            await self._pool.execute(
                """
                INSERT INTO spendsense.txn_override (
                    txn_id, user_id, category_code, subcategory_code, txn_type
                )
                VALUES ($1, $2, $3, $4, $5)
                """,
                txn_id,
                user_id,
                data.category_code,
                data.subcategory_code,
                txn_type,
            )
        
        # If channel provided, update txn_fact (channel column may exist in later schema versions)
        # Note: If channel column doesn't exist, this will fail gracefully
        if data.channel:
            try:
                await self._pool.execute(
                    """
                    UPDATE spendsense.txn_fact
                    SET channel = $1
                    WHERE txn_id = $2 AND user_id = $3
                    """,
                    data.channel.strip().lower(),
                    txn_id,
                    user_id,
                )
            except Exception as e:
                # Channel column might not exist in all schema versions
                logger.warning(f"Could not update channel for manual transaction: {e}")
        
        # Return transaction from effective view
        row = await self._pool.fetchrow(
            """
            SELECT
                v.txn_id,
                v.txn_date,
                COALESCE(
                    v.merchant_name_norm,
                    CASE 
                        WHEN v.description IS NOT NULL 
                             AND LENGTH(TRIM(v.description)) > 0 
                             AND LENGTH(TRIM(v.description)) <= 50
                        THEN INITCAP(REGEXP_REPLACE(TRIM(v.description), '\\s+', ' ', 'g'))
                        ELSE 'Unknown'
                    END
                ) AS merchant_name,
                COALESCE(dc.category_name, v.category_code) AS category_name,
                COALESCE(ds.subcategory_name, v.subcategory_code) AS subcategory_name,
                v.bank_code,
                v.channel,
                v.amount,
                v.direction
            FROM spendsense.vw_txn_effective v
            LEFT JOIN spendsense.dim_category dc ON dc.category_code = v.category_code
            LEFT JOIN spendsense.dim_subcategory ds ON ds.subcategory_code = v.subcategory_code
            WHERE v.txn_id = $1 AND v.user_id = $2
            """,
            txn_id,
            user_id,
        )
        
        if not row:
            raise ValueError("Failed to retrieve created transaction")
        
        return TransactionRecord(
            txn_id=str(row["txn_id"]),
            txn_date=row["txn_date"],
            merchant=row["merchant_name"],
            category=row["category_name"],
            subcategory=row["subcategory_name"],
            bank_code=row["bank_code"],
            channel=row["channel"],
            amount=float(row["amount"]),
            direction=row["direction"],
        )

    async def delete_transaction(self, user_id: str, txn_id: str) -> bool:
        """Delete a transaction. Returns True if deleted, False if not found."""
        # Verify transaction belongs to user and delete
        query = """
        DELETE FROM spendsense.txn_fact
        WHERE txn_id = $1 AND user_id = $2
        """
        result = await self._pool.execute(query, txn_id, user_id)
        deleted_count = int(result.split()[-1]) if result else 0
        return deleted_count > 0

    async def get_categories(self, user_id: str | None = None) -> list[dict[str, str]]:
        """Get all active categories (system + user's custom)."""
        if user_id:
            query = """
            SELECT category_code, category_name, is_custom, txn_type
            FROM spendsense.dim_category
            WHERE active = TRUE AND (user_id = $1 OR user_id IS NULL)
            ORDER BY is_custom, display_order, category_name
            """
            rows = await self._pool.fetch(query, user_id)
        else:
            query = """
            SELECT category_code, category_name, is_custom, txn_type
            FROM spendsense.dim_category
            WHERE active = TRUE AND user_id IS NULL
            ORDER BY display_order, category_name
            """
            rows = await self._pool.fetch(query)
        return [
            {
                "category_code": row["category_code"],
                "category_name": row["category_name"],
                "is_custom": row.get("is_custom", False),
                "txn_type": row.get("txn_type", "wants"),  # Default to 'wants' if not set
            }
            for row in rows
        ]

    async def get_subcategories(
        self, category_code: str | None = None, user_id: str | None = None
    ) -> list[dict[str, str]]:
        """Get all active subcategories, optionally filtered by category."""
        if category_code:
            if user_id:
                query = """
                SELECT subcategory_code, subcategory_name, category_code, is_custom
                FROM spendsense.dim_subcategory
                WHERE active = TRUE AND category_code = $1 
                    AND (user_id = $2 OR user_id IS NULL)
                ORDER BY is_custom, display_order, subcategory_name
                """
                rows = await self._pool.fetch(query, category_code, user_id)
            else:
                query = """
                SELECT subcategory_code, subcategory_name, category_code, is_custom
                FROM spendsense.dim_subcategory
                WHERE active = TRUE AND category_code = $1 AND user_id IS NULL
                ORDER BY display_order, subcategory_name
                """
                rows = await self._pool.fetch(query, category_code)
        else:
            if user_id:
                query = """
                SELECT subcategory_code, subcategory_name, category_code, is_custom
                FROM spendsense.dim_subcategory
                WHERE active = TRUE AND (user_id = $1 OR user_id IS NULL)
                ORDER BY category_code, is_custom, display_order, subcategory_name
                """
                rows = await self._pool.fetch(query, user_id)
            else:
                query = """
                SELECT subcategory_code, subcategory_name, category_code, is_custom
                FROM spendsense.dim_subcategory
                WHERE active = TRUE AND user_id IS NULL
                ORDER BY category_code, display_order, subcategory_name
                """
                rows = await self._pool.fetch(query)
        return [
            {
                "subcategory_code": row["subcategory_code"],
                "subcategory_name": row["subcategory_name"],
                "category_code": row["category_code"],
                "is_custom": row.get("is_custom", False),
            }
            for row in rows
        ]
    
    async def create_custom_category(
        self,
        user_id: str,
        category_code: str,
        category_name: str,
        txn_type: str = "wants",
    ) -> dict[str, str]:
        """Create a custom category for the user."""
        # Get max display_order for user's custom categories
        max_order = await self._pool.fetchval(
            """
            SELECT COALESCE(MAX(display_order), 1000) + 1
            FROM spendsense.dim_category
            WHERE user_id = $1
            """,
            user_id,
        ) or 1000
        
        await self._pool.execute(
            """
            INSERT INTO spendsense.dim_category (
                category_code, category_name, txn_type, display_order, active, user_id, is_custom
            )
            VALUES ($1, $2, $3, $4, TRUE, $5, TRUE)
            ON CONFLICT (category_code, user_id) DO UPDATE SET
                category_name = EXCLUDED.category_name,
                active = TRUE
            """,
            category_code,
            category_name,
            txn_type,
            max_order,
            user_id,
        )
        
        return {"code": category_code, "name": category_name, "is_custom": True}
    
    async def create_custom_subcategory(
        self,
        user_id: str,
        subcategory_code: str,
        subcategory_name: str,
        category_code: str,
    ) -> dict[str, str]:
        """Create a custom subcategory for the user."""
        # Verify category exists (system or user's custom)
        category_exists = await self._pool.fetchval(
            """
            SELECT 1 FROM spendsense.dim_category
            WHERE category_code = $1 AND active = TRUE
                AND (user_id = $2 OR user_id IS NULL)
            """,
            category_code,
            user_id,
        )
        if not category_exists:
            raise ValueError(f"Category '{category_code}' not found")
        
        # Get max display_order for user's custom subcategories in this category
        max_order = await self._pool.fetchval(
            """
            SELECT COALESCE(MAX(display_order), 1000) + 1
            FROM spendsense.dim_subcategory
            WHERE category_code = $1 AND user_id = $2
            """,
            category_code,
            user_id,
        ) or 1000
        
        await self._pool.execute(
            """
            INSERT INTO spendsense.dim_subcategory (
                subcategory_code, subcategory_name, category_code, display_order, active, user_id, is_custom
            )
            VALUES ($1, $2, $3, $4, TRUE, $5, TRUE)
            ON CONFLICT (subcategory_code, user_id) DO UPDATE SET
                subcategory_name = EXCLUDED.subcategory_name,
                active = TRUE
            """,
            subcategory_code,
            subcategory_name,
            category_code,
            max_order,
            user_id,
        )
        
        return {
            "code": subcategory_code,
            "name": subcategory_name,
            "category_code": category_code,
            "is_custom": True,
        }

    async def re_enrich_transactions(self, user_id: str) -> int:
        """Delete existing enriched records and re-run enrichment with updated merchant rules."""
        # Delete existing enriched records
        # Join through txn_parsed to get parsed_id from txn_fact.txn_id
        await self._pool.execute("""
            DELETE FROM spendsense.txn_enriched 
            WHERE parsed_id IN (
                SELECT tp.parsed_id
                FROM spendsense.txn_parsed tp
                JOIN spendsense.txn_fact tf ON tp.fact_txn_id = tf.txn_id
                WHERE tf.user_id = $1
            )
        """, user_id)
        
        # Re-run enrichment
        # We need a connection, not a pool, so we'll get one from the pool
        conn = await self._pool.acquire()
        try:
            enriched_count = await enrich_transactions(conn, user_id, upload_id=None)
        finally:
            await self._pool.release(conn)
        
        return enriched_count

    async def refresh_materialized_views(self, user_id: str) -> None:
        """Refresh materialized views for KPI calculations."""
        async with self._pool.acquire() as conn:
            await conn.execute(
                """
                REFRESH MATERIALIZED VIEW CONCURRENTLY spendsense.mv_spendsense_dashboard_user_month;
                REFRESH MATERIALIZED VIEW CONCURRENTLY spendsense.mv_spendsense_dashboard_user_month_category;
                """
            )
            logger.info(f"Refreshed materialized views for user {user_id}")

    async def get_available_months(self, user_id: str) -> list[str]:
        """Get list of available months with transaction data in YYYY-MM format."""
        rows = await self._pool.fetch(
            """
            SELECT DISTINCT DATE_TRUNC('month', txn_date)::date AS month
            FROM spendsense.txn_fact
            WHERE user_id = $1
            ORDER BY month DESC
            """,
            user_id,
        )
        return [row["month"].strftime("%Y-%m") for row in rows]

    async def get_insights(self, user_id: str, start_date: date | None = None, end_date: date | None = None) -> dict[str, Any]:
        """Get comprehensive insights including time-series, category breakdown, trends, and recurring transactions."""
        
        # Default to last 12 months if no date range provided
        if not end_date:
            end_date = date.today()
        if not start_date:
            from datetime import timedelta
            start_date = end_date - timedelta(days=365)
        
        # 1. Time-series data (monthly spending)
        time_series_rows = await self._pool.fetch(
            """
            SELECT 
                DATE_TRUNC('month', tf.txn_date)::date AS month,
                SUM(CASE WHEN tf.direction = 'credit' THEN tf.amount ELSE 0 END) AS income,
                SUM(CASE WHEN tf.direction = 'debit' THEN tf.amount ELSE 0 END) AS expenses
            FROM spendsense.txn_fact tf
            WHERE tf.user_id = $1
              AND tf.txn_date >= $2
              AND tf.txn_date <= $3
            GROUP BY DATE_TRUNC('month', tf.txn_date)
            ORDER BY month ASC
            """,
            user_id,
            start_date,
            end_date,
        )
        
        time_series = [
            {
                "date": row["month"].strftime("%Y-%m"),
                "value": float(row["expenses"] or 0),
                "label": row["month"].strftime("%b %Y")
            }
            for row in time_series_rows
        ]
        
        # 2. Category breakdown (current period)
        category_rows = await self._pool.fetch(
            """
            SELECT 
                COALESCE(te.category_id, 'uncategorized') AS category_code,
                COALESCE(dc.category_name, 'Uncategorized') AS category_name,
                COUNT(*) AS txn_count,
                SUM(CASE WHEN tf.direction = 'debit' THEN tf.amount ELSE 0 END) AS total_amount
            FROM spendsense.txn_fact tf
            LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
            LEFT JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
            LEFT JOIN spendsense.dim_category dc ON dc.category_code = te.category_id
            WHERE tf.user_id = $1
              AND tf.txn_date >= $2
              AND tf.txn_date <= $3
              AND tf.direction = 'debit'
            GROUP BY te.category_id, dc.category_name
            HAVING SUM(CASE WHEN tf.direction = 'debit' THEN tf.amount ELSE 0 END) > 0
            ORDER BY total_amount DESC
            """,
            user_id,
            start_date,
            end_date,
        )
        
        total_spend = sum(float(row["total_amount"] or 0) for row in category_rows)
        
        category_breakdown = [
            {
                "category_code": row["category_code"],
                "category_name": row["category_name"],
                "amount": float(row["total_amount"] or 0),
                "percentage": (float(row["total_amount"] or 0) / total_spend * 100) if total_spend > 0 else 0,
                "transaction_count": row["txn_count"],
                "avg_transaction": float(row["total_amount"] or 0) / row["txn_count"] if row["txn_count"] > 0 else 0,
            }
            for row in category_rows
        ]
        
        # 3. Spending trends (monthly breakdown by needs/wants/assets)
        trend_rows = await self._pool.fetch(
            """
            SELECT 
                DATE_TRUNC('month', tf.txn_date)::date AS month,
                SUM(CASE WHEN tf.direction = 'credit' THEN tf.amount ELSE 0 END) AS income,
                SUM(CASE WHEN tf.direction = 'debit' THEN tf.amount ELSE 0 END) AS expenses,
                SUM(CASE WHEN tf.direction = 'debit' AND COALESCE(dc.txn_type, 'wants') = 'needs' THEN tf.amount ELSE 0 END) AS needs,
                SUM(CASE WHEN tf.direction = 'debit' AND COALESCE(dc.txn_type, 'wants') = 'wants' THEN tf.amount ELSE 0 END) AS wants,
                SUM(CASE WHEN tf.direction = 'debit' AND COALESCE(dc.txn_type, 'wants') = 'assets' THEN tf.amount ELSE 0 END) AS assets
            FROM spendsense.txn_fact tf
            LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
            LEFT JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
            LEFT JOIN spendsense.dim_category dc ON dc.category_code = te.category_id
            WHERE tf.user_id = $1
              AND tf.txn_date >= $2
              AND tf.txn_date <= $3
            GROUP BY DATE_TRUNC('month', tf.txn_date)
            ORDER BY month ASC
            """,
            user_id,
            start_date,
            end_date,
        )
        
        spending_trends = [
            {
                "period": row["month"].strftime("%Y-%m"),
                "income": float(row["income"] or 0),
                "expenses": float(row["expenses"] or 0),
                "net": float(row["income"] or 0) - float(row["expenses"] or 0),
                "needs": float(row["needs"] or 0),
                "wants": float(row["wants"] or 0),
                "assets": float(row["assets"] or 0),
            }
            for row in trend_rows
        ]
        
        # 4. Recurring transactions detection
        recurring_rows = await self._pool.fetch(
            """
            WITH merchant_transactions AS (
                SELECT 
                    COALESCE(te.merchant_name, tp.counterparty_name, tf.merchant_name_norm) AS merchant_name,
                    te.category_id,
                    te.subcategory_id,
                    tf.amount,
                    tf.txn_date,
                    COUNT(*) OVER (PARTITION BY COALESCE(te.merchant_name, tp.counterparty_name, tf.merchant_name_norm), te.category_id) AS txn_count
                FROM spendsense.txn_fact tf
                LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
                LEFT JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
                WHERE tf.user_id = $1
                  AND tf.txn_date >= $2
                  AND tf.txn_date <= $3
                  AND tf.direction = 'debit'
                  AND COALESCE(te.merchant_name, tp.counterparty_name, tf.merchant_name_norm) IS NOT NULL
            ),
            recurring_candidates AS (
                SELECT 
                    merchant_name,
                    category_id,
                    subcategory_id,
                    COUNT(*) AS occurrence_count,
                    AVG(amount) AS avg_amount,
                    SUM(amount) AS total_amount,
                    MIN(txn_date) AS first_occurrence,
                    MAX(txn_date) AS last_occurrence,
                    COUNT(DISTINCT DATE_TRUNC('month', txn_date)) AS distinct_months
                FROM merchant_transactions
                WHERE txn_count >= 3  -- At least 3 occurrences
                GROUP BY merchant_name, category_id, subcategory_id
                HAVING COUNT(*) >= 3
            )
            SELECT 
                rc.merchant_name,
                rc.category_id AS category_code,
                COALESCE(dc.category_name, rc.category_id) AS category_name,
                rc.subcategory_id AS subcategory_code,
                COALESCE(ds.subcategory_name, rc.subcategory_id) AS subcategory_name,
                rc.occurrence_count AS transaction_count,
                rc.avg_amount,
                rc.total_amount,
                rc.last_occurrence,
                CASE 
                    WHEN rc.distinct_months >= 2 AND rc.occurrence_count / rc.distinct_months >= 0.8 THEN 'monthly'
                    WHEN rc.occurrence_count >= 20 THEN 'daily'
                    WHEN rc.occurrence_count >= 10 THEN 'weekly'
                    ELSE 'irregular'
                END AS frequency,
                (rc.last_occurrence + INTERVAL '1 month')::date AS next_expected
            FROM recurring_candidates rc
            LEFT JOIN spendsense.dim_category dc ON dc.category_code = rc.category_id
            LEFT JOIN spendsense.dim_subcategory ds ON ds.subcategory_code = rc.subcategory_id
            ORDER BY rc.total_amount DESC
            LIMIT 20
            """,
            user_id,
            start_date,
            end_date,
        )
        
        recurring_transactions = [
            {
                "merchant_name": row["merchant_name"],
                "category_code": row["category_code"],
                "category_name": row["category_name"],
                "subcategory_code": row["subcategory_code"],
                "subcategory_name": row["subcategory_name"],
                "frequency": row["frequency"],
                "avg_amount": float(row["avg_amount"] or 0),
                "last_occurrence": row["last_occurrence"].isoformat() if row["last_occurrence"] else None,
                "next_expected": row["next_expected"].isoformat() if row["next_expected"] else None,
                "transaction_count": row["transaction_count"],
                "total_amount": float(row["total_amount"] or 0),
            }
            for row in recurring_rows
        ]
        
        # 5. Spending patterns (day of week, time patterns)
        pattern_rows = await self._pool.fetch(
            """
            SELECT 
                TO_CHAR(tf.txn_date, 'Day') AS day_of_week,
                COUNT(*) AS txn_count,
                SUM(CASE WHEN tf.direction = 'debit' THEN tf.amount ELSE 0 END) AS total_amount
            FROM spendsense.txn_fact tf
            WHERE tf.user_id = $1
              AND tf.txn_date >= $2
              AND tf.txn_date <= $3
              AND tf.direction = 'debit'
            GROUP BY TO_CHAR(tf.txn_date, 'Day')
            ORDER BY total_amount DESC
            """,
            user_id,
            start_date,
            end_date,
        )
        
        spending_patterns = [
            {
                "day_of_week": row["day_of_week"].strip(),
                "amount": float(row["total_amount"] or 0),
                "transaction_count": row["txn_count"],
            }
            for row in pattern_rows
        ]
        
        # 6. Top merchants
        top_merchants_rows = await self._pool.fetch(
            """
            SELECT 
                COALESCE(te.merchant_name, tp.counterparty_name, tf.merchant_name_norm, 'Unknown') AS merchant_name,
                COUNT(*) AS txn_count,
                SUM(CASE WHEN tf.direction = 'debit' THEN tf.amount ELSE 0 END) AS total_spend,
                AVG(CASE WHEN tf.direction = 'debit' THEN tf.amount ELSE 0 END) AS avg_spend,
                MAX(tf.txn_date) AS last_transaction
            FROM spendsense.txn_fact tf
            LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
            LEFT JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
            WHERE tf.user_id = $1
              AND tf.txn_date >= $2
              AND tf.txn_date <= $3
              AND tf.direction = 'debit'
            GROUP BY COALESCE(te.merchant_name, tp.counterparty_name, tf.merchant_name_norm, 'Unknown')
            HAVING COUNT(*) >= 2
            ORDER BY total_spend DESC
            LIMIT 15
            """,
            user_id,
            start_date,
            end_date,
        )
        
        top_merchants = [
            {
                "merchant_name": row["merchant_name"],
                "transaction_count": row["txn_count"],
                "total_spend": float(row["total_spend"] or 0),
                "avg_spend": float(row["avg_spend"] or 0),
                "last_transaction": row["last_transaction"].isoformat() if row["last_transaction"] else None,
            }
            for row in top_merchants_rows
        ]
        
        return {
            "time_series": time_series,
            "category_breakdown": category_breakdown,
            "spending_trends": spending_trends,
            "recurring_transactions": recurring_transactions,
            "spending_patterns": spending_patterns,
            "top_merchants": top_merchants,
            "anomalies": None,  # TODO: Implement anomaly detection
        }

