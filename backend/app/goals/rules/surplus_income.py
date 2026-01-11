"""Surplus income detection rule - suggests allocating extra income to goals."""

import logging
from datetime import date, timedelta
from typing import Any
from uuid import UUID

from app.goals.rules.base_rule import GoalRule
from app.goals.goal_realtime_engine import TransactionView

logger = logging.getLogger(__name__)


class SurplusIncomeRule(GoalRule):
    """Detects income above baseline and suggests allocation."""

    name = "surplus_income"
    description = "Detects income above baseline and suggests allocation."
    priority = 20
    enabled = True

    async def apply(
        self,
        user_id: UUID,
        txn: TransactionView,
        context: dict,
        svc: Any,
        today: date,
    ) -> None:
        """Detect surplus income and suggest allocation to goals."""
        try:
            if txn.direction != "credit":
                return

            # Check if this is an income transaction
            if not txn.category or txn.category.lower() not in {"income", "salary", "bonus"}:
                return

            # Get expected monthly income baseline (simplified - could be from DB)
            # For now, use a heuristic based on context
            baseline = context.get("monthly_investible_capacity")
            if not baseline or baseline <= 0:
                # Try to infer from context or use a default
                baseline = 50000.0  # Default assumption

            # Calculate total income for current month
            month_start = txn.txn_date.replace(day=1)
            month_end = (month_start.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)

            # Get total income for this month (simplified - would need actual query)
            # For now, if this transaction alone exceeds baseline, consider it surplus
            if txn.amount > baseline * 1.2:  # 20% above baseline
                surplus = txn.amount - baseline

                # Get goals sorted by drift
                goals = await svc.repo.list_goals(user_id)
                if not goals:
                    return

                # Sort by drift percentage (highest first)
                goals_with_drift = [
                    g for g in goals if float(g.get("drift_pct") or 0.0) > 0
                ]
                goals_with_drift.sort(
                    key=lambda g: float(g.get("drift_pct") or 0.0), reverse=True
                )

                if not goals_with_drift:
                    # If no drifting goals, pick top priority goal
                    goals.sort(key=lambda g: g.get("priority_rank") or 999)
                    top_goal = goals[0]
                else:
                    top_goal = goals_with_drift[0]

                goal_id = UUID(str(top_goal["goal_id"]))
                goal_name = top_goal.get("goal_name", "your top goal")
                allocate_pool = surplus * 0.3  # Suggest 30% allocation

                await svc.suggestions.insert_suggestion(
                    user_id=user_id,
                    goal_id=goal_id,
                    suggestion_type="ALLOCATE_SURPLUS",
                    title="You received extra income this month",
                    description=(
                        f"You earned about ₹{int(surplus):,} more than your usual income this month. "
                        f"If you allocate ₹{int(allocate_pool):,} to {goal_name}, you can improve its timeline."
                    ),
                    action_payload={
                        "total_surplus": surplus,
                        "allocate_pool": allocate_pool,
                        "per_goal": allocate_pool,
                        "goal_id": str(top_goal["goal_id"]),
                    },
                )
        except Exception as e:
            logger.error(f"[SurplusIncomeRule] Error applying rule: {e}", exc_info=True)

