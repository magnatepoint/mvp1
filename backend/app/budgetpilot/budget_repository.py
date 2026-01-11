"""BudgetPilot repository for database operations."""

from typing import Any
from uuid import UUID
from datetime import date

import asyncpg


class BudgetRepository:
    """Repository for BudgetPilot database operations."""

    def __init__(self, conn: asyncpg.Connection):
        self.conn = conn

    async def get_plan_templates(self, active_only: bool = True) -> list[dict[str, Any]]:
        """Get all budget plan templates."""
        query = """
            SELECT plan_code, name, description, base_needs_pct, base_wants_pct,
                   base_assets_pct, eligibility_json, is_active, display_order
            FROM budgetpilot.budget_plan_master
        """
        if active_only:
            query += " WHERE is_active = TRUE"
        query += " ORDER BY display_order ASC"
        
        rows = await self.conn.fetch(query)
        return [dict(row) for row in rows]

    async def get_user_recommendations(
        self, user_id: UUID, month: date | None = None
    ) -> list[dict[str, Any]]:
        """Get budget recommendations for a user for a specific month."""
        if month is None:
            # Use current month
            month = date.today().replace(day=1)
        else:
            month = month.replace(day=1)
        
        rows = await self.conn.fetch(
            """
            SELECT reco_id, user_id, month, plan_code, needs_budget_pct,
                   wants_budget_pct, savings_budget_pct, score, recommendation_reason, created_at
            FROM budgetpilot.user_budget_recommendation
            WHERE user_id = $1 AND month = $2
            ORDER BY score DESC
            LIMIT 3
            """,
            user_id,
            month,
        )
        return [dict(row) for row in rows]

    async def get_user_commit(
        self, user_id: UUID, month: date | None = None
    ) -> dict[str, Any] | None:
        """Get user's committed budget for a month."""
        if month is None:
            month = date.today().replace(day=1)
        else:
            month = month.replace(day=1)
        
        row = await self.conn.fetchrow(
            """
            SELECT user_id, month, plan_code, alloc_needs_pct, alloc_wants_pct,
                   alloc_assets_pct, notes, committed_at
            FROM budgetpilot.user_budget_commit
            WHERE user_id = $1 AND month = $2
            """,
            user_id,
            month,
        )
        return dict(row) if row else None

    async def commit_budget(
        self,
        user_id: UUID,
        month: date,
        plan_code: str,
        alloc_needs_pct: float,
        alloc_wants_pct: float,
        alloc_assets_pct: float,
        notes: str | None = None,
    ) -> None:
        """Commit a budget plan for a user."""
        month = month.replace(day=1)
        
        await self.conn.execute(
            """
            INSERT INTO budgetpilot.user_budget_commit
                (user_id, month, plan_code, alloc_needs_pct, alloc_wants_pct, alloc_assets_pct, notes)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            ON CONFLICT (user_id, month) DO UPDATE
            SET plan_code = EXCLUDED.plan_code,
                alloc_needs_pct = EXCLUDED.alloc_needs_pct,
                alloc_wants_pct = EXCLUDED.alloc_wants_pct,
                alloc_assets_pct = EXCLUDED.alloc_assets_pct,
                notes = EXCLUDED.notes,
                committed_at = NOW()
            """,
            user_id,
            month,
            plan_code,
            alloc_needs_pct,
            alloc_wants_pct,
            alloc_assets_pct,
            notes,
        )

    async def get_goal_allocations(
        self, user_id: UUID, month: date | None = None
    ) -> list[dict[str, Any]]:
        """Get goal-level allocations for a user's committed budget."""
        if month is None:
            month = date.today().replace(day=1)
        else:
            month = month.replace(day=1)
        
        rows = await self.conn.fetch(
            """
            SELECT 
                ubcga.ubcga_id, 
                ubcga.user_id, 
                ubcga.month, 
                ubcga.goal_id, 
                ubcga.weight_pct, 
                ubcga.planned_amount, 
                ubcga.created_at,
                g.goal_name
            FROM budgetpilot.user_budget_commit_goal_alloc ubcga
            LEFT JOIN goal.user_goals_master g ON g.goal_id = ubcga.goal_id
            WHERE ubcga.user_id = $1 AND ubcga.month = $2
            ORDER BY ubcga.weight_pct DESC
            """,
            user_id,
            month,
        )
        return [dict(row) for row in rows]

    async def set_goal_allocations(
        self,
        user_id: UUID,
        month: date,
        goal_allocations: list[dict[str, Any]],
    ) -> None:
        """Set goal-level allocations for a committed budget."""
        month = month.replace(day=1)
        
        # Delete existing allocations for this month
        await self.conn.execute(
            """
            DELETE FROM budgetpilot.user_budget_commit_goal_alloc
            WHERE user_id = $1 AND month = $2
            """,
            user_id,
            month,
        )
        
        # Insert new allocations
        for alloc in goal_allocations:
            await self.conn.execute(
                """
                INSERT INTO budgetpilot.user_budget_commit_goal_alloc
                    (user_id, month, goal_id, weight_pct, planned_amount)
                VALUES ($1, $2, $3, $4, $5)
                ON CONFLICT (user_id, month, goal_id) DO UPDATE
                SET weight_pct = EXCLUDED.weight_pct,
                    planned_amount = EXCLUDED.planned_amount,
                    created_at = NOW()
                """,
                user_id,
                month,
                UUID(alloc["goal_id"]),
                alloc["weight_pct"],
                alloc["planned_amount"],
            )

    async def get_month_aggregate(
        self, user_id: UUID, month: date | None = None
    ) -> dict[str, Any] | None:
        """Get monthly aggregate (actuals vs planned) for a user."""
        if month is None:
            month = date.today().replace(day=1)
        else:
            month = month.replace(day=1)
        
        row = await self.conn.fetchrow(
            """
            SELECT user_id, month, income_amt,
                   needs_amt, planned_needs_amt, variance_needs_amt,
                   wants_amt, planned_wants_amt, variance_wants_amt,
                   assets_amt, planned_assets_amt, variance_assets_amt,
                   computed_at
            FROM budgetpilot.budget_user_month_aggregate
            WHERE user_id = $1 AND month = $2
            """,
            user_id,
            month,
        )
        return dict(row) if row else None

    async def get_user_spending_pattern(
        self, user_id: UUID, months_back: int = 3
    ) -> dict[str, Any] | None:
        """Get user's spending pattern from vw_txn_effective."""
        rows = await self.conn.fetch(
            """
            SELECT 
                date_trunc('month', txn_date) AS month,
                SUM(CASE WHEN txn_type = 'income' AND direction = 'credit' THEN amount ELSE 0 END) AS income_amt,
                SUM(CASE WHEN txn_type = 'needs' AND direction = 'debit' THEN amount ELSE 0 END) AS needs_amt,
                SUM(CASE WHEN txn_type = 'wants' AND direction = 'debit' THEN amount ELSE 0 END) AS wants_amt,
                SUM(CASE WHEN txn_type = 'assets' AND direction = 'debit' THEN amount ELSE 0 END) AS assets_amt
            FROM spendsense.vw_txn_effective
            WHERE user_id = $1
              AND txn_date >= date_trunc('month', CURRENT_DATE) - ($2 || ' months')::INTERVAL
              AND txn_date < date_trunc('month', CURRENT_DATE)
            GROUP BY date_trunc('month', txn_date)
            ORDER BY month DESC
            """,
            user_id,
            str(months_back),
        )
        
        if not rows:
            return None
        
        # Calculate averages
        total_income = sum(float(row["income_amt"] or 0) for row in rows)
        total_needs = sum(float(row["needs_amt"] or 0) for row in rows)
        total_wants = sum(float(row["wants_amt"] or 0) for row in rows)
        total_assets = sum(float(row["assets_amt"] or 0) for row in rows)
        
        avg_income = total_income / len(rows) if rows else 0
        avg_needs = total_needs / len(rows) if rows else 0
        avg_wants = total_wants / len(rows) if rows else 0
        avg_assets = total_assets / len(rows) if rows else 0
        
        return {
            "avg_income": avg_income,
            "avg_needs": avg_needs,
            "avg_wants": avg_wants,
            "avg_assets": avg_assets,
            "needs_ratio": avg_needs / avg_income if avg_income > 0 else 0,
            "wants_ratio": avg_wants / avg_income if avg_income > 0 else 0,
            "assets_ratio": avg_assets / avg_income if avg_income > 0 else 0,
            "months_analyzed": len(rows),
        }

    async def get_user_goals(self, user_id: UUID) -> list[dict[str, Any]]:
        """Get active goals for a user."""
        rows = await self.conn.fetch(
            """
            SELECT goal_id, goal_category, goal_name, goal_type, linked_txn_type,
                   estimated_cost, target_date, current_savings, priority_rank, status
            FROM goal.user_goals_master
            WHERE user_id = $1 AND status = 'active'
            ORDER BY priority_rank ASC NULLS LAST
            """,
            user_id,
        )
        return [dict(row) for row in rows]

    async def get_goal_attributes(self, user_id: UUID) -> dict[str, dict[str, Any]]:
        """Get goal attributes for a user."""
        rows = await self.conn.fetch(
            """
            SELECT goal_id, essentiality_score, urgency_score, dependency_score,
                   affordability_score, suggested_monthly_amount
            FROM budgetpilot.user_goal_attributes
            WHERE user_id = $1
            """,
            user_id,
        )
        return {str(row["goal_id"]): dict(row) for row in rows}

