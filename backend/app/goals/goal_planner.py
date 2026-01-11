"""Goal planning, prioritization, and projection logic."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Any

from dateutil.relativedelta import relativedelta


@dataclass
class PlannedGoal:
    """A goal with its planned monthly contribution and projected completion."""

    goal_id: str
    monthly_contribution: float
    projected_completion_date: date | None


class GoalPlanner:
    """Encapsulates goal prioritization and planning logic."""

    @staticmethod
    def compute_priority_score(goal: dict[str, Any]) -> float:
        """
        Higher score = higher priority.

        Factors:
        - Must-have vs good-to-have
        - Importance (1-5)
        - Time urgency (closer target date = more urgent)
        - Timeline flexibility (rigid > somewhat_flexible > flexible)
        """
        base = float(goal.get("importance") or 3)

        # must-have multiplier
        must_have_weight = 1.5 if goal.get("is_must_have", True) else 1.0

        # timeline flexibility
        flex_map = {
            "rigid": 1.3,
            "somewhat_flexible": 1.0,
            "flexible": 0.8,
        }
        flex_weight = flex_map.get(
            goal.get("timeline_flexibility") or "somewhat_flexible", 1.0
        )

        # time urgency: if target_date is close, bump score
        urgency_weight = 1.0
        target_date = goal.get("target_date")
        if target_date:
            if isinstance(target_date, str):
                target_date = date.fromisoformat(target_date)
            today = date.today()
            days = max((target_date - today).days, 1)
            # under 1 year: boost; beyond that: less boost
            if days <= 365:
                urgency_weight = 1.3
            elif days <= 3 * 365:
                urgency_weight = 1.1

        return base * must_have_weight * flex_weight * urgency_weight

    @classmethod
    def assign_priority_ranks(cls, goals: list[dict[str, Any]]) -> list[dict[str, Any]]:
        """Compute and set priority_rank on goal dictionaries (in-memory)."""
        scored = [(g, cls.compute_priority_score(g)) for g in goals]
        scored.sort(key=lambda t: t[1], reverse=True)

        for idx, (goal, _) in enumerate(scored, start=1):
            goal["priority_rank"] = idx

        return [g for g, _ in scored]

    @staticmethod
    def _months_to_reach(
        remaining_amount: float, monthly_contribution: float
    ) -> int | None:
        """Calculate months needed to reach goal."""
        if monthly_contribution <= 0 or remaining_amount <= 0:
            return None
        months = int((remaining_amount / monthly_contribution) + 0.9999)
        return max(months, 1)

    @classmethod
    def build_monthly_plan(
        cls,
        context: dict[str, Any],
        goals: list[dict[str, Any]],
    ) -> list[PlannedGoal]:
        """
        Allocate monthly capacity across goals by priority.

        Simple strategy:
        - Use monthly_investible_capacity (fallback default if None).
        - Compute weights from priority scores.
        - Allocate proportional contributions.
        - Compute projected completion date per goal.
        """
        if not goals:
            return []

        capacity = context.get("monthly_investible_capacity") or 0.0
        # fallback default if not provided
        if capacity <= 0:
            capacity = 10000.0  # INR 10k placeholder / safe default – can tune

        # ensure priority_rank exists
        goals = cls.assign_priority_ranks(goals)

        scores = [cls.compute_priority_score(g) for g in goals]
        total_score = sum(scores) or 1.0

        planned: list[PlannedGoal] = []
        today = date.today()

        for goal, score in zip(goals, scores):
            weight = score / total_score
            monthly_contribution = capacity * weight

            # Convert Decimal to float if needed (PostgreSQL returns Decimal)
            current_savings = float(goal.get("current_savings") or 0.0)
            estimated_cost = float(goal.get("estimated_cost") or 0.0)
            remaining = max(estimated_cost - current_savings, 0.0)
            months = cls._months_to_reach(remaining, monthly_contribution)
            projected_date = None
            if months is not None:
                projected_date = today + relativedelta(months=months)

            planned.append(
                PlannedGoal(
                    goal_id=str(goal.get("goal_id", "")),
                    monthly_contribution=monthly_contribution,
                    projected_completion_date=projected_date,
                )
            )

        return planned

    @staticmethod
    def compute_progress_pct(goal: dict[str, Any]) -> float:
        """Calculate progress percentage for a goal."""
        estimated_cost = float(goal.get("estimated_cost") or 0.0)
        if estimated_cost <= 0:
            return 0.0
        
        current_savings = float(goal.get("current_savings") or 0.0)
        return max(min(100.0 * current_savings / estimated_cost, 100.0), 0.0)

    @staticmethod
    def compute_milestones(progress_pct: float) -> list[int]:
        """Calculate which milestones have been achieved."""
        milestones = [25, 50, 75, 100]
        return [m for m in milestones if progress_pct >= m]

