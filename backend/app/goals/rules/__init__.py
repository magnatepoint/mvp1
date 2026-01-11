"""Goal Compass rule engine - auto-registers all rules on import."""

# Import registry first
from app.goals.rules.registry import RuleRegistry

# Import all rule implementations
from app.goals.rules.drift_rule import DriftRule
from app.goals.rules.surplus_income import SurplusIncomeRule
from app.goals.rules.overspending import OverspendingRule

# Register all rules at import time (sorted by priority)
RuleRegistry.register(DriftRule())
RuleRegistry.register(SurplusIncomeRule())
RuleRegistry.register(OverspendingRule())

__all__ = [
    "RuleRegistry",
    "DriftRule",
    "SurplusIncomeRule",
    "OverspendingRule",
]
