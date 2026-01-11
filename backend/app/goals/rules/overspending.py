"""Overspending detection rule - detects budget overruns and links to goals."""

import logging
from datetime import date, timedelta
from typing import Any
from uuid import UUID

from app.goals.rules.base_rule import GoalRule
from app.goals.goal_realtime_engine import TransactionView

logger = logging.getLogger(__name__)


class OverspendingRule(GoalRule):
    """Detect overspending vs budget and link to goal delays."""

    name = "overspending"
    description = "Detect overspending vs budget and link to goal delays"
    priority = 30
    enabled = True

    async def apply(
        self,
        user_id: UUID,
        txn: TransactionView,
        context: dict,
        svc: Any,
        today: date,
    ) -> None:
        """Detect overspending and create signals/suggestions."""
        try:
            # Only look at debit spending categories
            if txn.direction != "debit":
                return

            if not txn.category:
                return

            spend_cats = {
                "food_dining",
                "shopping",
                "travel",
                "entertainment",
                "lifestyle",
                "dining",
            }
            cat = txn.category.lower()

            if cat not in spend_cats:
                return

            # For now, use a simple heuristic: if monthly spend exceeds a threshold
            # In production, you'd query actual budget from DB
            # Simplified: assume budget is 20% of monthly investible capacity
            monthly_capacity = context.get("monthly_investible_capacity") or 50000.0
            estimated_budget = monthly_capacity * 0.2  # 20% for discretionary

            # Calculate month spend (simplified - would need actual aggregation)
            month_start = txn.txn_date.replace(day=1)
            month_end = (month_start.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)

            # For now, if this single transaction is significant, check
            # In production, you'd aggregate all transactions for this category this month
            if txn.amount > estimated_budget * 0.3:  # Single txn > 30% of monthly budget
                # This is a significant spend - create a warning
                await svc.signals.insert_signal(
                    user_id=user_id,
                    goal_id=None,
                    signal_type="OVERSPEND",
                    severity="warning",
                    message=(
                        f"Large spending detected in {cat.replace('_', ' ').title()}: "
                        f"₹{int(txn.amount):,}. This may impact your goal progress."
                    ),
                    meta={
                        "category": cat,
                        "amount": float(txn.amount),
                        "txn_id": str(txn.id),
                    },
                )

                # Get top drifting goal to suggest redirecting savings
                goals = await svc.repo.list_goals(user_id)
                if goals:
                    goals_with_drift = [
                        g for g in goals if float(g.get("drift_pct") or 0.0) > 0
                    ]
                    if goals_with_drift:
                        goals_with_drift.sort(
                            key=lambda g: float(g.get("drift_pct") or 0.0), reverse=True
                        )
                        top_goal = goals_with_drift[0]
                        goal_id = UUID(str(top_goal["goal_id"]))
                        goal_name = top_goal.get("goal_name", "your goal")

                        await svc.suggestions.insert_suggestion(
                            user_id=user_id,
                            goal_id=goal_id,
                            suggestion_type="CUT_EXPENSE",
                            title=f"Redirect spending to {goal_name}",
                            description=(
                                f"Consider reducing discretionary spending in {cat.replace('_', ' ').title()} "
                                f"and redirecting savings to {goal_name} to stay on track."
                            ),
                            action_payload={
                                "category": cat,
                                "suggested_reduction": float(txn.amount) * 0.5,
                                "goal_id": str(top_goal["goal_id"]),
                            },
                        )
        except Exception as e:
            logger.error(f"[OverspendingRule] Error applying rule: {e}", exc_info=True)

