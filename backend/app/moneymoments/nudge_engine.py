"""MoneyMoments nudge engine - rule evaluation and candidate generation."""

import json
import logging
from datetime import date, timedelta
from typing import Any
from uuid import UUID

from .money_moments_repository import MoneyMomentsRepository

logger = logging.getLogger(__name__)


class NudgeEngine:
    """Engine that evaluates rules and generates nudge candidates."""

    def __init__(self, repo: MoneyMomentsRepository):
        self.repo = repo

    async def evaluate_rules(
        self, user_id: UUID, as_of_date: date | None = None
    ) -> list[dict[str, Any]]:
        """
        Evaluate all active rules against user signals and generate candidates.
        
        Returns list of candidate dicts with:
        - rule_id, template_code, score, reason_json
        """
        if as_of_date is None:
            as_of_date = date.today()

        # 1. Get user's daily signal
        signal = await self._get_user_signal(user_id, as_of_date)
        if not signal:
            logger.info(f"No signal found for user {user_id} on {as_of_date}")
            return []

        # 2. Get active rules
        rules = await self._get_active_rules()
        if not rules:
            return []

        # 3. Get user traits (for segment filtering)
        traits = await self._get_user_traits(user_id)

        # 4. Get recent deliveries (for cooldown checking)
        recent_deliveries = await self._get_recent_deliveries(user_id, as_of_date)

        candidates = []

        for rule in rules:
            # Check cooldown
            if await self._is_in_cooldown(rule, recent_deliveries, as_of_date):
                continue

            # Check segment criteria
            if not await self._matches_segment(rule, traits):
                continue

            # Evaluate trigger conditions
            matches, score, reason = await self._evaluate_rule(rule, signal)
            if not matches:
                continue

            # Get template for this rule
            template = await self._get_template_for_rule(rule["rule_id"])
            if not template:
                continue

            candidates.append({
                "rule_id": rule["rule_id"],
                "template_code": template["template_code"],
                "score": score,
                "reason_json": reason,
            })

        # Sort by priority (from rule) and score, take top candidates
        # Group by rule priority first
        rule_priorities = {r["rule_id"]: r.get("priority", 100) for r in rules}
        candidates.sort(
            key=lambda c: (rule_priorities.get(c["rule_id"], 100), -c["score"]),
        )

        return candidates

    async def _get_user_signal(
        self, user_id: UUID, as_of_date: date
    ) -> dict[str, Any] | None:
        """Get user's daily signal."""
        row = await self.repo.conn.fetchrow(
            """
            SELECT user_id, as_of_date, dining_txn_7d, dining_spend_7d,
                   shopping_txn_7d, shopping_spend_7d, travel_txn_30d, travel_spend_30d,
                   wants_share_30d, recurring_merchants_90d, wants_vs_plan_pct,
                   assets_vs_plan_pct, rank1_goal_underfund_amt, rank1_goal_underfund_pct
            FROM moneymoments.mm_signal_daily
            WHERE user_id = $1 AND as_of_date = $2
            """,
            user_id,
            as_of_date,
        )
        return dict(row) if row else None

    async def _get_active_rules(self) -> list[dict[str, Any]]:
        """Get all active nudge rules."""
        rows = await self.repo.conn.fetch(
            """
            SELECT rule_id, name, description, target_domain, segment_criteria_json,
                   trigger_conditions_json, score_formula_json, cooldown_days, daily_cap, priority
            FROM moneymoments.mm_nudge_rule_master
            WHERE active = TRUE
            ORDER BY priority ASC
            """
        )
        return [dict(row) for row in rows]

    async def _get_user_traits(self, user_id: UUID) -> dict[str, Any] | None:
        """Get user traits."""
        row = await self.repo.conn.fetchrow(
            """
            SELECT user_id, age_band, gender, region_code, lifestyle_tags
            FROM moneymoments.mm_user_traits
            WHERE user_id = $1
            """,
            user_id,
        )
        return dict(row) if row else None

    async def _get_recent_deliveries(
        self, user_id: UUID, as_of_date: date, days: int = 30
    ) -> list[dict[str, Any]]:
        """Get recent nudge deliveries for cooldown checking."""
        rows = await self.repo.conn.fetch(
            """
            SELECT delivery_id, user_id, rule_id, sent_at
            FROM moneymoments.mm_nudge_delivery_log
            WHERE user_id = $1
              AND sent_at >= $2::date - ($3 || ' days')::INTERVAL
            ORDER BY sent_at DESC
            """,
            user_id,
            as_of_date,
            str(days),
        )
        return [dict(row) for row in rows]

    async def _is_in_cooldown(
        self,
        rule: dict[str, Any],
        recent_deliveries: list[dict[str, Any]],
        as_of_date: date,
    ) -> bool:
        """Check if rule is in cooldown period."""
        cooldown_days = rule.get("cooldown_days", 7)
        rule_id = rule["rule_id"]

        for delivery in recent_deliveries:
            if delivery["rule_id"] != rule_id:
                continue
            sent_at = delivery["sent_at"]
            if isinstance(sent_at, date):
                days_since = (as_of_date - sent_at).days
            else:
                days_since = (as_of_date - sent_at.date()).days
            if days_since < cooldown_days:
                return True

        return False

    async def _matches_segment(
        self, rule: dict[str, Any], traits: dict[str, Any] | None
    ) -> bool:
        """Check if user matches rule's segment criteria."""
        segment_criteria_raw = rule.get("segment_criteria_json") or {}
        # Parse JSONB if it's a string
        if isinstance(segment_criteria_raw, str):
            try:
                segment_criteria = json.loads(segment_criteria_raw)
            except (json.JSONDecodeError, TypeError):
                logger.warning(f"Failed to parse segment_criteria_json for rule {rule.get('rule_id')}: {segment_criteria_raw}")
                segment_criteria = {}
        elif isinstance(segment_criteria_raw, dict):
            segment_criteria = segment_criteria_raw
        else:
            segment_criteria = {}
        
        if not segment_criteria or not traits:
            return True  # No segment criteria means all users match

        # Simple segment matching (can be extended)
        # For now, just return True - segment logic can be added later
        return True

    async def _evaluate_rule(
        self, rule: dict[str, Any], signal: dict[str, Any]
    ) -> tuple[bool, float, dict[str, Any]]:
        """
        Evaluate a rule against user signal.
        
        Returns (matches, score, reason_json)
        """
        conditions_raw = rule.get("trigger_conditions_json") or {}
        # Parse JSONB if it's a string
        if isinstance(conditions_raw, str):
            try:
                conditions = json.loads(conditions_raw)
            except (json.JSONDecodeError, TypeError):
                logger.warning(f"Failed to parse trigger_conditions_json for rule {rule.get('rule_id')}: {conditions_raw}")
                return (False, 0.0, {})
        elif isinstance(conditions_raw, dict):
            conditions = conditions_raw
        else:
            conditions = {}
        
        if not conditions:
            return (False, 0.0, {})

        matches = True
        reason: dict[str, Any] = {}

        # Evaluate each condition
        for key, condition in conditions.items():
            if key.startswith("exclude_if_"):
                # Exclusion condition: "exclude_if_rank1_goal_underfund_amt_lt": 1000
                # Extract the field name and operator from the key
                exclude_key = key.replace("exclude_if_", "")
                
                # Handle suffix-based operators: _lt, _gt, _lte, _gte
                if exclude_key.endswith("_lt"):
                    exclude_key = exclude_key[:-3]  # Remove "_lt"
                    exclude_op = "lt"
                    exclude_val = condition if not isinstance(condition, dict) else list(condition.values())[0]
                elif exclude_key.endswith("_gt"):
                    exclude_key = exclude_key[:-3]  # Remove "_gt"
                    exclude_op = "gt"
                    exclude_val = condition if not isinstance(condition, dict) else list(condition.values())[0]
                elif exclude_key.endswith("_lte"):
                    exclude_key = exclude_key[:-4]  # Remove "_lte"
                    exclude_op = "lte"
                    exclude_val = condition if not isinstance(condition, dict) else list(condition.values())[0]
                elif exclude_key.endswith("_gte"):
                    exclude_key = exclude_key[:-4]  # Remove "_gte"
                    exclude_op = "gte"
                    exclude_val = condition if not isinstance(condition, dict) else list(condition.values())[0]
                else:
                    # Fallback: try to extract from dict format
                    exclude_op = list(condition.keys())[0] if isinstance(condition, dict) else None
                    exclude_val = list(condition.values())[0] if isinstance(condition, dict) else condition

                signal_val = signal.get(exclude_key)
                if signal_val is None:
                    continue

                signal_float = float(signal_val)
                val_float = float(exclude_val)

                if exclude_op == "lt" and signal_float < val_float:
                    matches = False
                    reason["excluded"] = f"{exclude_key} < {val_float}"
                    break
                elif exclude_op == "gt" and signal_float > val_float:
                    matches = False
                    reason["excluded"] = f"{exclude_key} > {val_float}"
                    break
                elif exclude_op == "lte" and signal_float <= val_float:
                    matches = False
                    reason["excluded"] = f"{exclude_key} <= {val_float}"
                    break
                elif exclude_op == "gte" and signal_float >= val_float:
                    matches = False
                    reason["excluded"] = f"{exclude_key} >= {val_float}"
                    break
            else:
                # Inclusion condition: "dining_txn_7d_min": 3 or "wants_share_30d_min": 0.30
                # Handle suffix-based operators: _min (>=), _max (<=)
                signal_key = key
                op = ">="
                val = condition
                
                if key.endswith("_min"):
                    signal_key = key[:-4]  # Remove "_min"
                    op = ">="
                    val = condition if not isinstance(condition, dict) else list(condition.values())[0]
                elif key.endswith("_max"):
                    signal_key = key[:-4]  # Remove "_max"
                    op = "<="
                    val = condition if not isinstance(condition, dict) else list(condition.values())[0]
                elif isinstance(condition, dict):
                    # Dict format: {"gte": 3} or {"lt": 100}
                    op = list(condition.keys())[0]
                    val = list(condition.values())[0]
                else:
                    # Direct value: defaults to >=
                    op = ">="
                    val = condition

                signal_val = signal.get(signal_key)
                if signal_val is None:
                    matches = False
                    reason["missing"] = signal_key
                    break

                signal_float = float(signal_val)
                val_float = float(val)

                if op == ">=" and signal_float < val_float:
                    matches = False
                    reason["failed"] = f"{signal_key} >= {val_float} (got {signal_float})"
                    break
                elif op == ">" and signal_float <= val_float:
                    matches = False
                    reason["failed"] = f"{signal_key} > {val_float} (got {signal_float})"
                    break
                elif op == "<=" and signal_float > val_float:
                    matches = False
                    reason["failed"] = f"{signal_key} <= {val_float} (got {signal_float})"
                    break
                elif op == "<" and signal_float >= val_float:
                    matches = False
                    reason["failed"] = f"{signal_key} < {val_float} (got {signal_float})"
                    break

                reason[signal_key] = signal_float

        # Compute score (simple for now)
        score = 0.5 if matches else 0.0
        if matches:
            # Boost score based on signal strength
            if signal.get("dining_txn_7d", 0) >= 5:
                score += 0.2
            if signal.get("wants_share_30d", 0) > 0.40:
                score += 0.2

        return (matches, min(1.0, score), reason)

    async def _get_template_for_rule(
        self, rule_id: str
    ) -> dict[str, Any] | None:
        """Get a template for a rule (prefer in_app channel)."""
        row = await self.repo.conn.fetchrow(
            """
            SELECT template_code, rule_id, channel, locale, title_template,
                   body_template, cta_text, cta_deeplink, humor_style
            FROM moneymoments.mm_nudge_template_master
            WHERE rule_id = $1 AND channel = 'in_app' AND active = TRUE
            ORDER BY created_at DESC
            LIMIT 1
            """,
            rule_id,
        )
        return dict(row) if row else None

    async def render_template(
        self,
        template: dict[str, Any],
        user_id: UUID,
        signal: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """
        Render a nudge template with variables filled in.
        
        Returns dict with title and body (rendered).
        """
        title_template = template.get("title_template", "")
        body_template = template.get("body_template", "")

        # Get user's top goal for variable substitution
        top_goal = await self._get_top_goal(user_id)
        goal_name = top_goal.get("goal_name", "your goal") if top_goal else "your goal"

        # Calculate save amount (example: 30% of average dining spend)
        save_amount = 0.0
        if signal:
            avg_dining = float(signal.get("dining_spend_7d", 0)) / max(
                float(signal.get("dining_txn_7d", 1)), 1
            )
            save_amount = avg_dining * 0.3

        # Replace variables
        title = title_template.replace("{{goal}}", goal_name).replace(
            "{{save}}", f"{int(save_amount):,}"
        )
        body = body_template.replace("{{goal}}", goal_name).replace(
            "{{save}}", f"{int(save_amount):,}"
        )

        return {
            "title": title,
            "body": body,
            "cta_text": template.get("cta_text"),
            "cta_deeplink": template.get("cta_deeplink"),
        }

    async def _get_top_goal(self, user_id: UUID) -> dict[str, Any] | None:
        """Get user's top priority goal."""
        row = await self.repo.conn.fetchrow(
            """
            SELECT goal_id, goal_name, priority_rank
            FROM goal.user_goals_master
            WHERE user_id = $1 AND status = 'active'
            ORDER BY priority_rank ASC NULLS LAST
            LIMIT 1
            """,
            user_id,
        )
        return dict(row) if row else None

