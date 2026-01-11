"""MoneyMoments repository for database operations."""

from typing import Any
from uuid import UUID
from datetime import date

import asyncpg


class MoneyMomentsRepository:
    """Repository for MoneyMoments database operations."""

    def __init__(self, conn: asyncpg.Connection):
        self.conn = conn

    async def get_user_moments(
        self, user_id: UUID, month: str | None = None, all_months: bool = False
    ) -> list[dict[str, Any]]:
        """Get money moments (behavioral insights) for a user."""
        import logging
        logger = logging.getLogger(__name__)
        
        query = """
            SELECT 
                user_id, 
                month, 
                habit_id, 
                value::float AS value, 
                label, 
                insight_text, 
                confidence::float AS confidence, 
                created_at
            FROM moneymoments.mm_user_moments
            WHERE user_id = $1
        """
        params: list[Any] = [user_id]
        
        if month:
            query += " AND month = $2"
            params.append(month)
            logger.info(f"Querying moments for user {user_id}, month={month}")
        elif not all_months:
            # Get latest month only (default behavior)
            query += " AND month = (SELECT MAX(month) FROM moneymoments.mm_user_moments WHERE user_id = $1)"
            logger.info(f"Querying moments for user {user_id}, latest month only")
        else:
            logger.info(f"Querying moments for user {user_id}, all months")
        
        query += " ORDER BY month DESC, confidence DESC, habit_id"
        
        rows = await self.conn.fetch(query, *params)
        result = []
        for row in rows:
            row_dict = dict(row)
            # Ensure value is a float (database might return it as string)
            if "value" in row_dict:
                try:
                    row_dict["value"] = float(row_dict["value"])
                except (ValueError, TypeError):
                    # If conversion fails, keep original value
                    pass
            # Ensure confidence is a float
            if "confidence" in row_dict:
                try:
                    row_dict["confidence"] = float(row_dict["confidence"])
                except (ValueError, TypeError):
                    pass
            result.append(row_dict)
        logger.info(f"Found {len(result)} moments for user {user_id}")
        return result

    async def store_moments(
        self, user_id: UUID, month: str, moments: list[dict[str, Any]]
    ) -> None:
        """Store computed money moments for a user."""
        # Delete existing moments for this month
        await self.conn.execute(
            """
            DELETE FROM moneymoments.mm_user_moments
            WHERE user_id = $1 AND month = $2
            """,
            user_id,
            month,
        )
        
        # Insert new moments
        for moment in moments:
            await self.conn.execute(
                """
                INSERT INTO moneymoments.mm_user_moments
                    (user_id, month, habit_id, value, label, insight_text, confidence)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                ON CONFLICT (user_id, month, habit_id) DO UPDATE
                SET value = EXCLUDED.value,
                    label = EXCLUDED.label,
                    insight_text = EXCLUDED.insight_text,
                    confidence = EXCLUDED.confidence,
                    created_at = NOW()
                """,
                user_id,
                month,
                moment["habit_id"],
                moment["value"],
                moment["label"],
                moment["insight_text"],
                moment["confidence"],
            )

    async def get_user_nudges(
        self, user_id: UUID, limit: int = 20
    ) -> list[dict[str, Any]]:
        """Get recent nudges delivered to a user."""
        rows = await self.conn.fetch(
            """
            SELECT 
                d.delivery_id,
                d.user_id,
                d.rule_id,
                d.template_code,
                d.channel,
                d.sent_at,
                d.send_status,
                d.metadata_json,
                t.title_template,
                t.body_template,
                t.cta_text,
                t.cta_deeplink,
                r.name AS rule_name
            FROM moneymoments.mm_nudge_delivery_log d
            JOIN moneymoments.mm_nudge_template_master t ON t.template_code = d.template_code
            JOIN moneymoments.mm_nudge_rule_master r ON r.rule_id = d.rule_id
            WHERE d.user_id = $1
            ORDER BY d.sent_at DESC
            LIMIT $2
            """,
            user_id,
            limit,
        )
        return [dict(row) for row in rows]

    async def log_nudge_interaction(
        self,
        user_id: UUID,
        delivery_id: UUID,
        event_type: str,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        """Log user interaction with a nudge."""
        await self.conn.execute(
            """
            INSERT INTO moneymoments.mm_nudge_interaction_log
                (delivery_id, user_id, event_type, metadata_json)
            VALUES ($1, $2, $3, $4)
            """,
            delivery_id,
            user_id,
            event_type,
            metadata or {},
        )

    async def create_nudge_candidates(
        self,
        user_id: UUID,
        as_of_date: date,
        candidates: list[dict[str, Any]],
    ) -> list[UUID]:
        """Create nudge candidates for a user."""
        candidate_ids = []
        for candidate in candidates:
            candidate_id = await self.conn.fetchval(
                """
                INSERT INTO moneymoments.mm_nudge_candidate
                    (user_id, as_of_date, rule_id, template_code, score, reason_json, status)
                VALUES ($1, $2, $3, $4, $5, $6, 'pending')
                ON CONFLICT (user_id, as_of_date, rule_id) DO UPDATE
                SET template_code = EXCLUDED.template_code,
                    score = EXCLUDED.score,
                    reason_json = EXCLUDED.reason_json,
                    status = 'pending',
                    created_at = NOW()
                RETURNING candidate_id
                """,
                user_id,
                as_of_date,
                candidate["rule_id"],
                candidate["template_code"],
                candidate["score"],
                candidate["reason_json"],
            )
            if candidate_id:
                candidate_ids.append(candidate_id)
        return candidate_ids

    async def get_user_suppression(
        self, user_id: UUID, channel: str = "in_app"
    ) -> dict[str, Any] | None:
        """Get user suppression settings."""
        row = await self.conn.fetchrow(
            """
            SELECT user_id, channel, muted_until, daily_cap
            FROM moneymoments.mm_user_suppression
            WHERE user_id = $1 AND channel = $2
            """,
            user_id,
            channel,
        )
        return dict(row) if row else None

    async def deliver_nudge(
        self,
        candidate_id: UUID,
        user_id: UUID,
        rule_id: str,
        template_code: str,
        channel: str,
        rendered_title: str,
        rendered_body: str,
        metadata: dict[str, Any] | None = None,
    ) -> UUID:
        """Create a delivery log entry for a nudge."""
        delivery_id = await self.conn.fetchval(
            """
            INSERT INTO moneymoments.mm_nudge_delivery_log
                (candidate_id, user_id, rule_id, template_code, channel, send_status, metadata_json)
            VALUES ($1, $2, $3, $4, $5, 'success', $6)
            RETURNING delivery_id
            """,
            candidate_id,
            user_id,
            rule_id,
            template_code,
            channel,
            metadata or {},
        )
        
        # Update candidate status
        await self.conn.execute(
            """
            UPDATE moneymoments.mm_nudge_candidate
            SET status = 'sent'
            WHERE candidate_id = $1
            """,
            candidate_id,
        )
        
        return delivery_id

    async def get_pending_candidates(
        self, user_id: UUID | None = None, limit: int = 100
    ) -> list[dict[str, Any]]:
        """Get pending nudge candidates ready for delivery."""
        query = """
            SELECT c.candidate_id, c.user_id, c.as_of_date, c.rule_id, c.template_code,
                   c.score, c.reason_json, c.created_at,
                   t.title_template, t.body_template, t.cta_text, t.cta_deeplink, t.channel
            FROM moneymoments.mm_nudge_candidate c
            JOIN moneymoments.mm_nudge_template_master t ON t.template_code = c.template_code
            WHERE c.status = 'pending'
        """
        params: list[Any] = []
        
        if user_id:
            query += " AND c.user_id = $1"
            params.append(user_id)
        
        query += " ORDER BY c.created_at ASC LIMIT $" + str(len(params) + 1)
        params.append(limit)
        
        rows = await self.conn.fetch(query, *params)
        return [dict(row) for row in rows]

    async def compute_daily_signal(
        self, user_id: UUID, as_of_date: date
    ) -> dict[str, Any] | None:
        """
        Compute or get daily signal for a user.
        This aggregates spending data for nudge rule evaluation.
        """
        # Check if signal already exists
        existing = await self.conn.fetchrow(
            """
            SELECT * FROM moneymoments.mm_signal_daily
            WHERE user_id = $1 AND as_of_date = $2
            """,
            user_id,
            as_of_date,
        )
        if existing:
            return dict(existing)

        # Compute signal from transactions
        signal_data = await self.conn.fetchrow(
            """
            WITH tx AS (
                SELECT 
                    v.user_id,
                    v.txn_date,
                    v.amount,
                    v.direction,
                    v.txn_type,
                    CASE 
                        WHEN v.category_code = 'dining' THEN 'Dining'
                        WHEN v.category_code = 'shopping' THEN 'Shopping'
                        WHEN v.category_code = 'travel' THEN 'Travel'
                        ELSE NULL
                    END AS major_category
                FROM spendsense.vw_txn_effective v
                WHERE v.user_id = $1
                  AND v.txn_date >= $2::date - INTERVAL '90 days'
                  AND v.txn_date < $2::date + INTERVAL '1 day'
            ),
            win_7 AS (
                SELECT 
                    user_id,
                    COUNT(*) FILTER (WHERE major_category='Dining' AND direction='debit') AS dining_txn_7d,
                    COALESCE(SUM(amount) FILTER (WHERE major_category='Dining' AND direction='debit'), 0) AS dining_spend_7d,
                    COUNT(*) FILTER (WHERE major_category='Shopping' AND direction='debit') AS shopping_txn_7d,
                    COALESCE(SUM(amount) FILTER (WHERE major_category='Shopping' AND direction='debit'), 0) AS shopping_spend_7d
                FROM tx
                WHERE txn_date >= $2::date - INTERVAL '7 days'
                GROUP BY user_id
            ),
            win_30 AS (
                SELECT 
                    user_id,
                    COUNT(*) FILTER (WHERE major_category='Travel' AND direction='debit') AS travel_txn_30d,
                    COALESCE(SUM(amount) FILTER (WHERE major_category='Travel' AND direction='debit'), 0) AS travel_spend_30d,
                    COALESCE(SUM(amount) FILTER (WHERE txn_type='wants' AND direction='debit'), 0) AS wants_total_30d,
                    COALESCE(SUM(amount) FILTER (WHERE txn_type='income' AND direction='credit'), 0) AS income_total_30d
                FROM tx
                WHERE txn_date >= $2::date - INTERVAL '30 days'
                GROUP BY user_id
            ),
            budget_var AS (
                SELECT 
                    b.user_id,
                    CASE 
                        WHEN b.planned_wants_amt > 0 
                        THEN (b.wants_amt / b.planned_wants_amt)::NUMERIC(6,3)
                        ELSE NULL
                    END AS wants_vs_plan_pct,
                    CASE 
                        WHEN b.planned_assets_amt > 0 
                        THEN (b.assets_amt / b.planned_assets_amt)::NUMERIC(6,3)
                        ELSE NULL
                    END AS assets_vs_plan_pct
                FROM budgetpilot.budget_user_month_aggregate b
                WHERE b.user_id = $1
                  AND b.month = date_trunc('month', $2::date)
                LIMIT 1
            ),
            goal_underfund AS (
                SELECT 
                    g.user_id,
                    COALESCE(MAX(GREATEST(0, g.estimated_cost - g.current_savings)), 0) AS rank1_goal_underfund_amt
                FROM goal.user_goals_master g
                WHERE g.user_id = $1
                  AND g.status = 'active'
                  AND g.priority_rank = 1
                GROUP BY g.user_id
            )
            SELECT 
                $1::UUID AS user_id,
                $2::date AS as_of_date,
                COALESCE(w7.dining_txn_7d, 0)::INTEGER AS dining_txn_7d,
                COALESCE(w7.dining_spend_7d, 0) AS dining_spend_7d,
                COALESCE(w7.shopping_txn_7d, 0)::INTEGER AS shopping_txn_7d,
                COALESCE(w7.shopping_spend_7d, 0) AS shopping_spend_7d,
                COALESCE(w30.travel_txn_30d, 0)::INTEGER AS travel_txn_30d,
                COALESCE(w30.travel_spend_30d, 0) AS travel_spend_30d,
                CASE 
                    WHEN w30.income_total_30d > 0 
                    THEN (w30.wants_total_30d / w30.income_total_30d)::NUMERIC(6,3)
                    ELSE NULL
                END AS wants_share_30d,
                0::INTEGER AS recurring_merchants_90d,
                COALESCE(bv.wants_vs_plan_pct, NULL) AS wants_vs_plan_pct,
                COALESCE(bv.assets_vs_plan_pct, NULL) AS assets_vs_plan_pct,
                COALESCE(gu.rank1_goal_underfund_amt, 0) AS rank1_goal_underfund_amt,
                CASE 
                    WHEN gu.rank1_goal_underfund_amt > 0 AND w30.income_total_30d > 0
                    THEN (gu.rank1_goal_underfund_amt / w30.income_total_30d)::NUMERIC(6,3)
                    ELSE NULL
                END AS rank1_goal_underfund_pct
            FROM win_7 w7
            FULL OUTER JOIN win_30 w30 ON w30.user_id = w7.user_id
            LEFT JOIN budget_var bv ON bv.user_id = COALESCE(w7.user_id, w30.user_id)
            LEFT JOIN goal_underfund gu ON gu.user_id = COALESCE(w7.user_id, w30.user_id)
            WHERE COALESCE(w7.user_id, w30.user_id) = $1
            """,
            user_id,
            as_of_date,
        )

        if not signal_data:
            return None

        signal_dict = dict(signal_data)

        # Insert or update signal
        await self.conn.execute(
            """
            INSERT INTO moneymoments.mm_signal_daily
                (user_id, as_of_date, dining_txn_7d, dining_spend_7d, shopping_txn_7d, shopping_spend_7d,
                 travel_txn_30d, travel_spend_30d, wants_share_30d, recurring_merchants_90d,
                 wants_vs_plan_pct, assets_vs_plan_pct, rank1_goal_underfund_amt, rank1_goal_underfund_pct)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
            ON CONFLICT (user_id, as_of_date) DO UPDATE
            SET dining_txn_7d = EXCLUDED.dining_txn_7d,
                dining_spend_7d = EXCLUDED.dining_spend_7d,
                shopping_txn_7d = EXCLUDED.shopping_txn_7d,
                shopping_spend_7d = EXCLUDED.shopping_spend_7d,
                travel_txn_30d = EXCLUDED.travel_txn_30d,
                travel_spend_30d = EXCLUDED.travel_spend_30d,
                wants_share_30d = EXCLUDED.wants_share_30d,
                recurring_merchants_90d = EXCLUDED.recurring_merchants_90d,
                wants_vs_plan_pct = EXCLUDED.wants_vs_plan_pct,
                assets_vs_plan_pct = EXCLUDED.assets_vs_plan_pct,
                rank1_goal_underfund_amt = EXCLUDED.rank1_goal_underfund_amt,
                rank1_goal_underfund_pct = EXCLUDED.rank1_goal_underfund_pct
            """,
            user_id,
            as_of_date,
            signal_dict["dining_txn_7d"],
            signal_dict["dining_spend_7d"],
            signal_dict["shopping_txn_7d"],
            signal_dict["shopping_spend_7d"],
            signal_dict["travel_txn_30d"],
            signal_dict["travel_spend_30d"],
            signal_dict["wants_share_30d"],
            signal_dict["recurring_merchants_90d"],
            signal_dict["wants_vs_plan_pct"],
            signal_dict["assets_vs_plan_pct"],
            signal_dict["rank1_goal_underfund_amt"],
            signal_dict["rank1_goal_underfund_pct"],
        )

        return signal_dict


