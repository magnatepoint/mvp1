"""Drift detection rule - creates signals when goals fall behind."""

import logging
from datetime import date
from typing import Any
from uuid import UUID

from app.goals.rules.base_rule import GoalRule
from app.goals.goal_realtime_engine import TransactionView

logger = logging.getLogger(__name__)


class DriftRule(GoalRule):
    """Creates signals when goal drift increases."""

    name = "drift_rule"
    description = "Creates signals when drift increases"
    priority = 40
    enabled = True

    async def apply(
        self,
        user_id: UUID,
        txn: TransactionView,
        context: dict,
        svc: Any,
        today: date,
    ) -> None:
        """Check all goals for drift and create signals."""
        try:
            goals = await svc.repo.list_goals(user_id)

            for g in goals:
                drift_pct = float(g.get("drift_pct") or 0.0)
                if drift_pct <= 0:
                    continue

                severity = "info"
                if drift_pct >= 10:
                    severity = "critical"
                elif drift_pct >= 5:
                    severity = "warning"

                goal_id = UUID(str(g["goal_id"]))
                goal_name = g.get("goal_name", "Goal")
                drift_amount = float(g.get("drift_amount") or 0.0)

                await svc.signals.insert_signal(
                    user_id=user_id,
                    goal_id=goal_id,
                    signal_type="DRIFT",
                    severity=severity,
                    message=(
                        f"{goal_name} is behind target by "
                        f"{drift_pct:.1f}% (₹{drift_amount:.0f} short vs plan)."
                    ),
                    meta={
                        "drift_pct": drift_pct,
                        "drift_amount": drift_amount,
                    },
                )

                # Create suggestion for drifting goals
                estimated_cost = float(g.get("estimated_cost") or 0.0)
                current_savings = float(g.get("current_savings") or 0.0)
                remaining = max(estimated_cost - current_savings, 0)

                if remaining > 0:
                    suggested_extra = remaining / 12.0  # rupees per month

                    await svc.suggestions.insert_suggestion(
                        user_id=user_id,
                        goal_id=goal_id,
                        suggestion_type="INCREASE_CONTRIBUTION",
                        title=f"Boost savings for {goal_name}",
                        description=(
                            f"If you increase your monthly contribution by about "
                            f"₹{suggested_extra:.0f}, you can get {goal_name} back on track."
                        ),
                        action_payload={
                            "suggested_extra_per_month": round(suggested_extra, 2),
                            "goal_id": str(g["goal_id"]),
                        },
                    )
        except Exception as e:
            logger.error(f"[DriftRule] Error applying rule: {e}", exc_info=True)

