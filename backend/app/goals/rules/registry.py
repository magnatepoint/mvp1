"""Rule registry for managing Goal Compass rules."""

from typing import List

from app.goals.rules.base_rule import GoalRule


class RuleRegistry:
    """Registry for managing and executing Goal Compass rules."""

    _rules: List[GoalRule] = []

    @classmethod
    def register(cls, rule: GoalRule) -> None:
        """Register a rule with the registry."""
        cls._rules.append(rule)
        cls._rules.sort(key=lambda r: r.priority)

    @classmethod
    def all_rules(cls) -> List[GoalRule]:
        """Get all enabled rules, sorted by priority."""
        return [r for r in cls._rules if r.enabled]

    @classmethod
    def get_rule(cls, name: str) -> GoalRule | None:
        """Get a rule by name."""
        for rule in cls._rules:
            if rule.name == name:
                return rule
        return None

    @classmethod
    def enable_rule(cls, name: str) -> None:
        """Enable a rule by name."""
        rule = cls.get_rule(name)
        if rule:
            rule.enabled = True

    @classmethod
    def disable_rule(cls, name: str) -> None:
        """Disable a rule by name."""
        rule = cls.get_rule(name)
        if rule:
            rule.enabled = False

    @classmethod
    def clear(cls) -> None:
        """Clear all registered rules (mainly for testing)."""
        cls._rules.clear()

