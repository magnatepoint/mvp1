"""BudgetPilot recommendation engine - rule-based budget plan selection."""

import logging
from datetime import date, timedelta
from typing import Any
from uuid import UUID

from .budget_repository import BudgetRepository

logger = logging.getLogger(__name__)


class RecommendationEngine:
    """Engine that generates personalized budget recommendations."""

    def __init__(self, repo: BudgetRepository):
        self.repo = repo

    async def generate_recommendations(
        self, user_id: UUID, target_month: date | None = None
    ) -> list[dict[str, Any]]:
        """
        Generate top 3 budget recommendations for a user.
        
        Returns list of recommendations with:
        - plan_code
        - needs_budget_pct, wants_budget_pct, savings_budget_pct
        - score
        - recommendation_reason
        - goal_preview (optional)
        """
        if target_month is None:
            target_month = date.today().replace(day=1)
        else:
            target_month = target_month.replace(day=1)

        # 1. Get user spending pattern
        spending = await self.repo.get_user_spending_pattern(user_id, months_back=3)
        if not spending or spending["avg_income"] <= 0:
            logger.warning(f"No spending data for user {user_id}, using default plan")
            return await self._get_default_recommendations(user_id, target_month)

        # 2. Get user goals
        goals = await self.repo.get_user_goals(user_id)
        goal_attrs = await self.repo.get_goal_attributes(user_id)

        # 3. Get all active plan templates
        templates = await self.repo.get_plan_templates(active_only=True)

        # 4. Score each template
        scored_plans = []
        for template in templates:
            score, reason = await self._score_plan(
                template, spending, goals, goal_attrs
            )
            scored_plans.append({
                "plan_code": template["plan_code"],
                "name": template["name"],
                "description": template.get("description"),
                "needs_budget_pct": float(template["base_needs_pct"]),
                "wants_budget_pct": float(template["base_wants_pct"]),
                "savings_budget_pct": float(template["base_assets_pct"]),
                "score": score,
                "recommendation_reason": reason,
            })

        # 5. Sort by score and take top 3
        scored_plans.sort(key=lambda x: x["score"], reverse=True)
        top_3 = scored_plans[:3]

        # 6. Add goal preview for each recommendation
        for plan in top_3:
            plan["goal_preview"] = await self._compute_goal_preview(
                user_id,
                goals,
                goal_attrs,
                spending["avg_income"],
                plan["savings_budget_pct"],
            )

        # 7. Store recommendations in DB
        await self._store_recommendations(user_id, target_month, top_3)

        return top_3

    async def _score_plan(
        self,
        template: dict[str, Any],
        spending: dict[str, Any],
        goals: list[dict[str, Any]],
        goal_attrs: dict[str, dict[str, Any]],
    ) -> tuple[float, str]:
        """
        Score a plan template based on user profile.
        Returns (score, reason) tuple.
        """
        wants_share = spending.get("wants_ratio", 0.30)
        assets_share = spending.get("assets_ratio", 0.10)
        avg_income = spending.get("avg_income", 0)

        template_wants = float(template["base_wants_pct"])
        template_assets = float(template["base_assets_pct"])
        plan_code = template["plan_code"]

        # Check for emergency goal
        has_emergency = any(
            g.get("goal_category", "").lower() == "emergency"
            for g in goals
        )
        emergency_gap = sum(
            max(0, float(g.get("estimated_cost", 0)) - float(g.get("current_savings", 0)))
            for g in goals
            if g.get("goal_category", "").lower() == "emergency"
        )

        # Check for debt goals
        has_debt = any(
            "debt" in g.get("goal_category", "").lower()
            or "loan" in g.get("goal_category", "").lower()
            for g in goals
        )

        # Scoring logic (weighted)
        score = 0.0

        # 1. Wants alignment (40% weight) - closer to current wants is better
        wants_alignment = 1.0 - abs(template_wants - wants_share)
        score += 0.40 * wants_alignment

        # 2. Assets boost when underfunded (30% weight)
        if assets_share < 0.15 or emergency_gap > 0:
            score += 0.30 * template_assets
        else:
            score += 0.30 * (1.0 - abs(template_assets - assets_share))

        # 3. Baseline bias for balanced plan (15% weight)
        if plan_code == "BAL_50_30_20":
            score += 0.15

        # 4. Emergency priority boost (15% weight)
        if plan_code == "EMERGENCY_FIRST" and emergency_gap > 0:
            score += 0.15
        elif plan_code == "DEBT_FIRST" and has_debt:
            score += 0.15
        elif plan_code == "GOAL_PRIORITY" and len(goals) >= 3:
            score += 0.15

        # Generate reason
        reason = self._generate_reason(
            plan_code, wants_share, assets_share, has_emergency, emergency_gap, has_debt
        )

        return (round(score, 3), reason)

    def _generate_reason(
        self,
        plan_code: str,
        wants_share: float,
        assets_share: float,
        has_emergency: bool,
        emergency_gap: float,
        has_debt: bool,
    ) -> str:
        """Generate human-readable recommendation reason."""
        if plan_code == "EMERGENCY_FIRST" and emergency_gap > 0:
            return f"Emergency gap detected (₹{emergency_gap:,.0f} short). Increase savings to accelerate buffer."
        elif plan_code == "DEBT_FIRST" and has_debt:
            return "Constrain wants and push needs to accelerate debt payoff."
        elif plan_code == "GOAL_PRIORITY":
            return "Direct more savings toward your top priorities."
        elif plan_code == "LEAN_BASICS":
            return "Tighten wants temporarily; keep savings momentum."
        elif wants_share > 0.40:
            return f"Your wants spending ({wants_share*100:.0f}%) is high. This plan helps rebalance."
        elif assets_share < 0.10:
            return f"Your savings rate ({assets_share*100:.0f}%) is below target. This plan boosts savings."
        else:
            return "Balanced budgeting for stability and growth."

    async def _compute_goal_preview(
        self,
        user_id: UUID,
        goals: list[dict[str, Any]],
        goal_attrs: dict[str, dict[str, Any]],
        monthly_income: float,
        savings_pct: float,
    ) -> list[dict[str, Any]]:
        """Compute goal allocation preview for a plan."""
        if not goals:
            return []

        # Calculate total savings budget
        savings_budget = monthly_income * savings_pct

        # Compute weights for each goal
        weights = []
        for goal in goals:
            goal_id = str(goal["goal_id"])
            priority_rank = goal.get("priority_rank") or 5
            attrs = goal_attrs.get(goal_id, {})

            # Weight = priority (inverse) + essentiality + urgency
            priority_weight = max(1, 6 - min(5, priority_rank))
            essentiality = attrs.get("essentiality_score", 50) / 25.0
            urgency = attrs.get("urgency_score", 50) / 25.0

            raw_weight = priority_weight + essentiality + urgency
            weights.append({
                "goal_id": goal_id,
                "goal_name": goal.get("goal_name", "Goal"),
                "raw_weight": raw_weight,
            })

        # Normalize weights
        total_weight = sum(w["raw_weight"] for w in weights)
        if total_weight == 0:
            return []

        for w in weights:
            w["allocation_pct"] = round(w["raw_weight"] / total_weight, 4)
            w["allocation_amount"] = round(savings_budget * w["allocation_pct"], 2)

        # Sort by allocation amount descending
        weights.sort(key=lambda x: x["allocation_amount"], reverse=True)

        return [
            {
                "goal_id": w["goal_id"],
                "goal_name": w["goal_name"],
                "allocation_pct": w["allocation_pct"],
                "allocation_amount": w["allocation_amount"],
            }
            for w in weights[:5]  # Top 5 goals
        ]

    async def _store_recommendations(
        self,
        user_id: UUID,
        month: date,
        recommendations: list[dict[str, Any]],
    ) -> None:
        """Store recommendations in database."""
        for rec in recommendations:
            try:
                await self.repo.conn.execute(
                    """
                    INSERT INTO budgetpilot.user_budget_recommendation
                        (user_id, month, plan_code, needs_budget_pct, wants_budget_pct,
                         savings_budget_pct, score, recommendation_reason)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                    ON CONFLICT (user_id, month, plan_code) DO UPDATE
                    SET needs_budget_pct = EXCLUDED.needs_budget_pct,
                        wants_budget_pct = EXCLUDED.wants_budget_pct,
                        savings_budget_pct = EXCLUDED.savings_budget_pct,
                        score = EXCLUDED.score,
                        recommendation_reason = EXCLUDED.recommendation_reason
                    """,
                    user_id,
                    month,
                    rec["plan_code"],
                    rec["needs_budget_pct"],
                    rec["wants_budget_pct"],
                    rec["savings_budget_pct"],
                    rec["score"],
                    rec["recommendation_reason"],
                )
            except Exception as e:
                logger.error(f"Failed to store recommendation: {e}", exc_info=True)

    async def _get_default_recommendations(
        self, user_id: UUID, month: date
    ) -> list[dict[str, Any]]:
        """Get default recommendations when no spending data available."""
        templates = await self.repo.get_plan_templates(active_only=True)
        # Return top 3 by display_order
        templates.sort(key=lambda x: x.get("display_order", 100))
        top_3 = templates[:3]

        return [
            {
                "plan_code": t["plan_code"],
                "name": t["name"],
                "description": t.get("description"),
                "needs_budget_pct": float(t["base_needs_pct"]),
                "wants_budget_pct": float(t["base_wants_pct"]),
                "savings_budget_pct": float(t["base_assets_pct"]),
                "score": 0.5,
                "recommendation_reason": "Default recommendation. Complete your profile for personalized plans.",
                "goal_preview": [],
            }
            for t in top_3
        ]

