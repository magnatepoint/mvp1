# Goal Compass Rule Engine

Production-ready, pluggable rule-engine architecture for Goal Compass.

## Architecture Overview

The rule engine allows you to:
- ✅ Add/remove rules without changing core code
- ✅ Manage rule priority & enable/disable rules per user or global
- ✅ Test each rule independently
- ✅ Expand later into AI-driven rules

## Structure

```
app/goals/rules/
├── base_rule.py      # Base rule interface (GoalRule ABC)
├── registry.py       # Rule registry for managing rules
├── __init__.py       # Auto-registration of all rules
├── drift_rule.py     # Drift detection rule
├── surplus_income.py # Surplus income detection rule
└── overspending.py   # Overspending detection rule
```

## How It Works

1. **Rule Interface**: All rules inherit from `GoalRule` and implement `apply()`
2. **Auto-Registration**: Rules are registered when `app.goals.rules` is imported
3. **Execution Pipeline**: `GoalRealtimeEngine` executes all enabled rules in priority order
4. **Service Injection**: Rules receive a `SimpleNamespace` with repos, planner, etc.

## Adding a New Rule

1. Create a new file in `app/goals/rules/` (e.g., `my_new_rule.py`)
2. Inherit from `GoalRule` and implement `apply()`
3. Register in `app/goals/rules/__init__.py`

Example:

```python
from app.goals.rules.base_rule import GoalRule

class MyNewRule(GoalRule):
    name = "my_new_rule"
    description = "Does something useful"
    priority = 50  # Lower = earlier execution
    enabled = True

    async def apply(self, user_id, txn, context, svc, today):
        # Your rule logic here
        pass
```

## Rule Priority

Rules execute in priority order (lower number = earlier):
- `surplus_income`: 20
- `overspending`: 30
- `drift_rule`: 40

## Dynamic Rule Configuration

The `goal.rule_config` table allows runtime control:
- Enable/disable rules
- Adjust priority
- Store rule-specific config in JSONB

## Testing

Each rule can be tested independently:

```python
from app.goals.rules.drift_rule import DriftRule

rule = DriftRule()
# Test with mock services
await rule.apply(user_id, txn, context, mock_svc, today)
```

## Future Enhancements

- AI-driven rules (spend prediction, goal consolidation)
- User-specific rule configurations
- Rule execution metrics and analytics
- Scheduled rules (e.g., MissedSIPRule)

