"""Base rule interface for Goal Compass rule engine."""

from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date
from typing import TYPE_CHECKING, Any
from uuid import UUID

if TYPE_CHECKING:
    from app.goals.goal_realtime_engine import TransactionView


class GoalRule(ABC):
    """
    Base class for all Goal Compass rules.
    All rules must inherit from this and implement the apply method.
    """

    name: str  # Unique rule name
    description: str  # What it does
    priority: int  # Lower = earlier execution
    enabled: bool  # Can be turned on/off dynamically

    @abstractmethod
    async def apply(
        self,
        user_id: UUID,
        txn: "TransactionView",
        context: dict[str, Any],
        engine_services: Any,  # repos + planner aggregated
        today: date,
    ) -> None:
        """
        Executes the rule.
        Must NOT raise exceptions — exceptions should be caught internally.
        """
        raise NotImplementedError

