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

    async def get_kpis(self, user_id: str) -> SpendSenseKPI:
        """Return dashboard KPIs from materialized views with graceful fallbacks."""
        try:
            row = await self._pool.fetchrow(
                """
                SELECT month,
                       income_amt,
                       needs_amt,
                       wants_amt,
                       assets_amt
                FROM spendsense.mv_spendsense_dashboard_user_month
                WHERE user_id = $1
                ORDER BY month DESC
                LIMIT 1
                """,
                user_id,
            )

            if not row:
                return await self._compute_kpis_fallback(user_id)

            month = row["month"]
            categories = await self._pool.fetch(
                """
                SELECT mc.category_code,
                       COALESCE(dc.category_name, mc.category_code) AS category_name,
                       mc.txn_count,
                       mc.spend_amount,
                       mc.income_amount
                FROM spendsense.mv_spendsense_dashboard_user_month_category mc
                LEFT JOIN spendsense.dim_category dc
                    ON dc.category_code = mc.category_code
                WHERE mc.user_id = $1
                  AND mc.month = $2
                ORDER BY mc.spend_amount DESC
                LIMIT 5
                """,
                user_id,
                month,
            )
            prev_month_map = await self._fetch_prev_month_category_spend(user_id, month)
            top_categories = self._build_category_badges(categories, prev_month_map)

            wants_gauge = self._build_wants_gauge(
                needs=float(row["needs_amt"] or 0),
                wants=float(row["wants_amt"] or 0),
            )

            best_month = await self._fetch_best_month_from_mv(
                user_id=user_id,
                current_month=month,
                current_net=float(row["income_amt"] or 0) - float(row["wants_amt"] or 0),
            )

            loot_drop = await self._fetch_recent_loot_drop(user_id)

            return SpendSenseKPI(
                month=month,
                income_amount=float(row["income_amt"] or 0),
                needs_amount=float(row["needs_amt"] or 0),
                wants_amount=float(row["wants_amt"] or 0),
                assets_amount=float(row["assets_amt"] or 0),
                top_categories=top_categories,
                wants_gauge=wants_gauge,
                best_month=best_month,
                recent_loot_drop=loot_drop,
            )
        except asyncpg.PostgresError as exc:
            logger.warning("KPI materialized view missing, using fallback: %s", exc)
            return await self._compute_kpis_fallback(user_id)
        except Exception as exc:
            logger.error("Failed to load KPIs: %s", exc)
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

    async def _compute_kpis_fallback(self, user_id: str) -> SpendSenseKPI:
        """Compute KPIs directly from txn_fact when MVs aren't available."""
        row = await self._pool.fetchrow(
            """
            WITH enriched AS (
                SELECT
                    f.txn_date,
                    f.amount,
                    f.direction,
                    COALESCE(e.category_code, 'uncategorized') AS category_code,
                    COALESCE(dc.txn_type, 'needs') AS txn_type
                FROM spendsense.txn_fact f
                LEFT JOIN spendsense.txn_enriched e ON e.txn_id = f.txn_id
                LEFT JOIN spendsense.dim_category dc ON dc.category_code = e.category_code
                WHERE f.user_id = $1
                  AND f.txn_date >= DATE_TRUNC('month', NOW())
            )
            SELECT
                DATE_TRUNC('month', NOW())::date AS month,
                COALESCE(SUM(CASE WHEN direction = 'credit' THEN amount ELSE 0 END), 0) AS income_amount,
                COALESCE(SUM(CASE WHEN txn_type = 'needs' THEN amount ELSE 0 END), 0) AS needs_amount,
                COALESCE(SUM(CASE WHEN txn_type = 'wants' THEN amount ELSE 0 END), 0) AS wants_amount,
                COALESCE(SUM(CASE WHEN txn_type = 'assets' THEN amount ELSE 0 END), 0) AS assets_amount
            FROM enriched
            """,
            user_id,
        )

        month: date | None = row["month"] if row else None

        categories = await self._pool.fetch(
            """
            SELECT
                COALESCE(e.category_code, 'uncategorized') AS category_code,
                COALESCE(dc.category_name, e.category_code, 'Uncategorized') AS category_name,
                COUNT(*) AS txn_count,
                SUM(CASE WHEN f.direction = 'debit' THEN f.amount ELSE 0 END) AS spend_amount,
                SUM(CASE WHEN f.direction = 'credit' THEN f.amount ELSE 0 END) AS income_amount
            FROM spendsense.txn_fact f
            LEFT JOIN spendsense.txn_enriched e ON e.txn_id = f.txn_id
            LEFT JOIN spendsense.dim_category dc ON dc.category_code = e.category_code
            WHERE f.user_id = $1
              AND f.txn_date >= DATE_TRUNC('month', NOW())
            GROUP BY 1, 2
            ORDER BY spend_amount DESC NULLS LAST
            LIMIT 5
            """,
            user_id,
        )

        prev_categories_rows = await self._pool.fetch(
            """
            SELECT
                COALESCE(e.category_code, 'uncategorized') AS category_code,
                SUM(CASE WHEN f.direction = 'debit' THEN f.amount ELSE 0 END) AS spend_amount
            FROM spendsense.txn_fact f
            LEFT JOIN spendsense.txn_enriched e ON e.txn_id = f.txn_id
            WHERE f.user_id = $1
              AND f.txn_date >= DATE_TRUNC('month', NOW() - INTERVAL '1 month')
              AND f.txn_date < DATE_TRUNC('month', NOW())
            GROUP BY 1
            """,
            user_id,
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
        rows = await self._pool.fetch(
            """
            SELECT category_code, spend_amount
            FROM spendsense.mv_spendsense_dashboard_user_month_category
            WHERE user_id = $1
              AND month = ($2::date - INTERVAL '1 month')::date
            """,
            user_id,
            current_month,
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
                LEFT JOIN spendsense.txn_enriched e ON e.txn_id = f.txn_id
                LEFT JOIN spendsense.dim_category dc ON dc.category_code = e.category_code
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
                    LEFT JOIN spendsense.txn_enriched e ON e.txn_id = f.txn_id
                    LEFT JOIN spendsense.dim_category dc ON dc.category_code = e.category_code
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
            income_amount=float(best_row_dict.get(income_key, 0) or 0),
            needs_amount=float(best_row_dict.get(needs_key, 0) or 0),
            wants_amount=float(best_row_dict.get(wants_key, 0) or 0),
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
            file_name=row["file_name"],
            transactions_ingested=transactions,
            status=row["status"],
            occurred_at=row["received_at"],
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
        source_type: SourceType = SourceType.FILE,
        pdf_password: str | None = None,
    ) -> UploadBatch:
        if not filename:
            raise SpendSenseParseError("Filename is required")

        async with self._pool.acquire() as conn:
            batch_id = await conn.fetchval(
                """
                INSERT INTO spendsense.upload_batch (user_id, source_type, file_name, status)
                VALUES ($1, $2, $3, 'received')
                RETURNING upload_id
                """,
                user_id,
                source_type.value,
                filename,
            )

        ingest_statement_file_task.delay(
            batch_id=str(batch_id),
            user_id=user_id,
            filename=filename,
            file_b64=base64.b64encode(file_bytes).decode("ascii"),
            pdf_password=pdf_password,
        )

        return UploadBatch(
            batch_id=str(batch_id),
            user_id=user_id,
            source_type=source_type,
            file_name=filename,
            total_rows=0,
            status="received",
        )

    async def get_batch_status(self, batch_id: str, user_id: str) -> UploadBatch | None:
        """Get the current status of an upload batch."""
        query = """
        SELECT upload_id, user_id, source_type, file_name, status, total_records, parsed_records, error_json
        FROM spendsense.upload_batch
        WHERE upload_id = $1 AND user_id = $2
        """
        row = await self._pool.fetchrow(query, batch_id, user_id)
        if not row:
            return None
        return UploadBatch(
            batch_id=str(row["upload_id"]),
            user_id=str(row["user_id"]),
            source_type=SourceType(row["source_type"]),
            file_name=row["file_name"],
            total_rows=row["total_records"] or 0,
            status=row["status"],
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
            add_clause("v.channel = ${idx}", channel)

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
                            '\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '^UPI-([^-]+)-' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^UPI-([^-]+)-'))[1],
                            '\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* 'UPI/([^/]+)/' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, 'UPI/([^/]+)/'))[1],
                            '\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '^IMPS-[^-]+-([^-]+)-' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^IMPS-[^-]+-([^-]+)-'))[1],
                            '\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '(NEFT|NEFT)[-/]([^-/\s]+)' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '(NEFT|NEFT)[-/]([^-/\s]+)'))[2],
                            '\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '^ACH\s+([^-/]+)' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^ACH\s+([^-/]+)'))[1],
                            '\s+', ' ', 'g'
                        ))
                    -- For simple descriptions, use the description itself (limited length)
                    WHEN v.description IS NOT NULL 
                         AND LENGTH(TRIM(v.description)) > 0 
                         AND LENGTH(TRIM(v.description)) <= 50
                         AND LOWER(TRIM(v.description)) NOT IN ('test transaction - today', 'salary', 'payment', 'transfer', 'debit', 'credit')
                         AND v.description !~* '^\d+$'
                    THEN INITCAP(REGEXP_REPLACE(TRIM(v.description), '\s+', ' ', 'g'))
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
        # Get original transaction and enriched data for feedback
        original_query = """
        SELECT 
            f.txn_id,
            f.merchant_name_norm,
            f.description,
            f.amount,
            f.direction,
            e.category_code AS original_category,
            e.subcategory_code AS original_subcategory
        FROM spendsense.txn_fact f
        LEFT JOIN spendsense.txn_enriched e ON e.txn_id = f.txn_id
        WHERE f.txn_id = $1 AND f.user_id = $2
        """
        original = await self._pool.fetchrow(original_query, txn_id, user_id)
        if not original:
            raise ValueError("Transaction not found or access denied")
        
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
                predictor_service = get_predictor_service()
                await predictor_service.record_feedback(
                    conn,
                    txn_id,
                    user_id,
                    original.get("original_category"),
                    original.get("original_subcategory"),
                    category_code,
                    subcategory_code,
                    original.get("merchant_name_norm"),
                    original.get("description"),
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
        
        # Insert new override
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
                            '\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '^UPI-([^-]+)-' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^UPI-([^-]+)-'))[1],
                            '\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* 'UPI/([^/]+)/' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, 'UPI/([^/]+)/'))[1],
                            '\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '^IMPS-[^-]+-([^-]+)-' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^IMPS-[^-]+-([^-]+)-'))[1],
                            '\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '(NEFT|NEFT)[-/]([^-/\s]+)' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '(NEFT|NEFT)[-/]([^-/\s]+)'))[2],
                            '\s+', ' ', 'g'
                        ))
                    WHEN v.description ~* '^ACH\s+([^-/]+)' THEN
                        INITCAP(REGEXP_REPLACE(
                            (regexp_match(v.description, '^ACH\s+([^-/]+)'))[1],
                            '\s+', ' ', 'g'
                        ))
                    -- For simple descriptions, use the description itself (limited length)
                    WHEN v.description IS NOT NULL 
                         AND LENGTH(TRIM(v.description)) > 0 
                         AND LENGTH(TRIM(v.description)) <= 50
                         AND LOWER(TRIM(v.description)) NOT IN ('test transaction - today', 'salary', 'payment', 'transfer', 'debit', 'credit')
                         AND v.description !~* '^\d+$'
                    THEN INITCAP(REGEXP_REPLACE(TRIM(v.description), '\s+', ' ', 'g'))
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
            SELECT category_code, category_name, is_custom
            FROM spendsense.dim_category
            WHERE active = TRUE AND (user_id = $1 OR user_id IS NULL)
            ORDER BY is_custom, display_order, category_name
            """
            rows = await self._pool.fetch(query, user_id)
        else:
            query = """
            SELECT category_code, category_name, is_custom
            FROM spendsense.dim_category
            WHERE active = TRUE AND user_id IS NULL
            ORDER BY display_order, category_name
            """
            rows = await self._pool.fetch(query)
        return [
            {
                "code": row["category_code"],
                "name": row["category_name"],
                "is_custom": row.get("is_custom", False),
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
                "code": row["subcategory_code"],
                "name": row["subcategory_name"],
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
        await self._pool.execute("""
            DELETE FROM spendsense.txn_enriched 
            WHERE txn_id IN (
                SELECT txn_id FROM spendsense.txn_fact WHERE user_id = $1
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

