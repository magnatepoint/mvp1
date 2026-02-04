"""Real-time goal engine that processes transactions and generates signals/suggestions."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from types import SimpleNamespace
from typing import Any
from uuid import UUID

from .goal_planner import GoalPlanner
from .goals_repository import GoalsRepository
from .signals_repository import GoalSignalsRepository
from .suggestions_repository import GoalSuggestionsRepository
from .rules.registry import RuleRegistry

# Import rules module to trigger auto-registration
# This ensures rules are registered even if main.py import doesn't run
try:
    import app.goals.rules  # noqa: F401
except ImportError:
    pass  # Rules may not be available in all contexts

logger = logging.getLogger(__name__)


@dataclass
class TransactionView:
    """Minimal view of a transaction needed for goal logic."""

    id: UUID
    user_id: UUID
    txn_date: date
    amount: float
    direction: str  # 'debit' or 'credit'
    category: str | None  # high-level category from enriched
    subcategory: str | None
    merchant_name: str | None


class GoalRealtimeEngine:
    """
    Applies new transactions to goal progress and generates signals/suggestions.
    """

    def __init__(
        self,
        goals_repo: GoalsRepository,
        signals_repo: GoalSignalsRepository,
        suggestions_repo: GoalSuggestionsRepository,
        planner: GoalPlanner | None = None,
    ):
        self.goals_repo = goals_repo
        self.signals_repo = signals_repo
        self.suggestions_repo = suggestions_repo
        self.planner = planner or GoalPlanner()

    async def process_transaction(
        self,
        user_id: UUID,
        txn: TransactionView,
        context: dict[str, Any] | None = None,
    ) -> None:
        """
        Main entry: call this after a transaction is created + categorized.
        """
        if not context:
            # Try to get context from database
            context = await self._get_life_context(user_id)
            if not context:
                logger.debug(f"No life context found for user {user_id}, skipping goal processing")
                return

        # 1) Find goals linked to this transaction category/subcategory
        goals = await self.goals_repo.list_goals(user_id)
        linked_goals = self._filter_linked_goals(goals, txn)

        if linked_goals:
            await self._apply_txn_to_goals(linked_goals, txn)

        # 2) Rebuild plan and update drift metrics
        await self._recalculate_plan_and_drift(user_id, context, goals)

        # 3) Execute all registered rules
        today = date.today()
        
        # Prepare grouped services for rule handlers
        svc = SimpleNamespace(
            repo=self.goals_repo,
            signals=self.signals_repo,
            suggestions=self.suggestions_repo,
            planner=self.planner,
        )

        # Execute all registered rules
        for rule in RuleRegistry.all_rules():
            try:
                await rule.apply(user_id, txn, context, svc, today)
            except Exception as e:
                logger.error(
                    f"[Rule Error] {rule.name}: {e}",
                    exc_info=True,
                )

    def _filter_linked_goals(
        self,
        goals: list[dict[str, Any]],
        txn: TransactionView,
    ) -> list[dict[str, Any]]:
        """
        Basic rules:
        - If goal.linked_txn_type matches txn.category → link
        - Optionally refine by subcategory later
        """
        if not txn.category:
            return []

        linked: list[dict[str, Any]] = []
        for g in goals:
            linked_txn_type = g.get("linked_txn_type")
            if not linked_txn_type:
                continue

            # Simple: match category; you can make this richer
            if linked_txn_type.lower() == txn.category.lower():
                linked.append(g)

        return linked

    async def _apply_txn_to_goals(
        self,
        goals: list[dict[str, Any]],
        txn: TransactionView,
    ) -> None:
        """
        Update goal current_savings / remaining_amount based on txn.
        Direction 'credit' assumed as contribution towards goal category.
        """
        for g in goals:
            goal_id = UUID(str(g["goal_id"]))
            current_savings = float(g.get("current_savings") or 0.0)

            if txn.direction == "credit":
                # Treat as contribution/top-up to goal
                new_savings = current_savings + txn.amount
                updates = {
                    "current_savings": new_savings,
                }
                # Add drift fields if they exist
                try:
                    updates["last_contribution_at"] = datetime.combine(txn.txn_date, datetime.min.time())
                    updates["last_txn_id"] = txn.id
                except Exception:
                    pass  # Fields might not exist yet
                
                await self.goals_repo.update_goal(
                    user_id=txn.user_id,
                    goal_id=goal_id,
                    updates=updates,
                )
                logger.debug(
                    f"Updated goal {goal_id} savings: {current_savings} -> {new_savings} "
                    f"from txn {txn.id}"
                )

    async def _recalculate_plan_and_drift(
        self,
        user_id: UUID,
        context: dict[str, Any],
        goals: list[dict[str, Any]],
    ) -> None:
        """
        Rebuild monthly plan with GoalPlanner and compute drift for each goal.
        """
        if not goals:
            return

        # Convert context dict to LifeContextRequest format if needed
        context_dict = context if isinstance(context, dict) else context.model_dump() if hasattr(context, 'model_dump') else {}

        planned = self.planner.build_monthly_plan(context=context_dict, goals=goals)
        planned_map = {pg.goal_id: pg for pg in planned}

        today = date.today()

        for g in goals:
            goal_id_str = str(g["goal_id"])
            planned_goal = planned_map.get(goal_id_str)

            if not planned_goal:
                continue

            # Expected savings by today = monthly_contribution * months_since_start
            # Simplified: assume plan started when goal created
            created_at = g.get("created_at")
            if isinstance(created_at, str):
                created_at = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
            elif isinstance(created_at, datetime):
                pass
            else:
                created_at = datetime.now()

            goal_created_date = created_at.date() if hasattr(created_at, 'date') else date.today()
            months_since = max(
                (today.year - goal_created_date.year) * 12
                + (today.month - goal_created_date.month),
                1,
            )

            expected = planned_goal.monthly_contribution * months_since
            actual = float(g.get("current_savings") or 0.0)

            drift_amount = max(expected - actual, 0.0)
            estimated_cost = float(g.get("estimated_cost") or 0.0)

            drift_pct = (
                (drift_amount / estimated_cost * 100.0)
                if estimated_cost > 0 and drift_amount > 0
                else 0.0
            )

            # Update drift fields (status remains unchanged - drift info is in drift_amount/drift_pct)
            goal_id = UUID(str(g["goal_id"]))
            await self.goals_repo.update_goal(
                user_id=user_id,
                goal_id=goal_id,
                updates={
                    "drift_amount": drift_amount,
                    "drift_pct": drift_pct,
                    # Note: status field only accepts: 'active', 'paused', 'completed', 'cancelled'
                    # Drift status can be determined from drift_pct if needed
                },
            )

    # Note: _generate_signals_and_suggestions removed - now handled by rules

    async def _get_life_context(self, user_id: UUID) -> dict[str, Any] | None:
        """Get life context from database."""
        try:
            row = await self.goals_repo.conn.fetchrow(
                """
                SELECT age_band, dependents_spouse, dependents_children_count,
                       dependents_parents_care, housing, employment, income_regularity,
                       region_code, emergency_opt_out,
                       monthly_investible_capacity, total_monthly_emi_obligations,
                       risk_profile_overall, review_frequency, notify_on_drift,
                       auto_adjust_on_income_change
                FROM goal.user_life_context
                WHERE user_id = $1
                """,
                user_id,
            )
            if row:
                return dict(row)
        except Exception as e:
            logger.debug(f"Could not fetch life context for user {user_id}: {e}")
        return None

