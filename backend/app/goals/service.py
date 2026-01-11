"""Service layer for Goals module."""

import logging
from datetime import date, datetime, timedelta
from typing import Any
from uuid import UUID

import asyncpg

from .goal_planner import GoalPlanner
from .goals_repository import GoalsRepository

logger = logging.getLogger(__name__)


class GoalsService:
    """Service for managing user financial goals."""

    def __init__(self, pool: asyncpg.Pool):
        """Initialize with database pool."""
        self.pool = pool

    async def save_life_context(
        self, user_id: UUID, context: dict[str, Any]
    ) -> dict[str, Any]:
        """Save or update user life context."""
        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO goal.user_life_context (
                    user_id, age_band, dependents_spouse, dependents_children_count,
                    dependents_parents_care, housing, employment, income_regularity,
                    region_code, emergency_opt_out,
                    monthly_investible_capacity, total_monthly_emi_obligations,
                    risk_profile_overall, review_frequency, notify_on_drift,
                    auto_adjust_on_income_change
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
                ON CONFLICT (user_id) DO UPDATE SET
                    age_band = EXCLUDED.age_band,
                    dependents_spouse = EXCLUDED.dependents_spouse,
                    dependents_children_count = EXCLUDED.dependents_children_count,
                    dependents_parents_care = EXCLUDED.dependents_parents_care,
                    housing = EXCLUDED.housing,
                    employment = EXCLUDED.employment,
                    income_regularity = EXCLUDED.income_regularity,
                    region_code = EXCLUDED.region_code,
                    emergency_opt_out = EXCLUDED.emergency_opt_out,
                    monthly_investible_capacity = EXCLUDED.monthly_investible_capacity,
                    total_monthly_emi_obligations = EXCLUDED.total_monthly_emi_obligations,
                    risk_profile_overall = EXCLUDED.risk_profile_overall,
                    review_frequency = EXCLUDED.review_frequency,
                    notify_on_drift = EXCLUDED.notify_on_drift,
                    auto_adjust_on_income_change = EXCLUDED.auto_adjust_on_income_change,
                    updated_at = NOW()
                """,
                user_id,
                context["age_band"],
                context["dependents_spouse"],
                context["dependents_children_count"],
                context["dependents_parents_care"],
                context["housing"],
                context["employment"],
                context["income_regularity"],
                context["region_code"],
                context.get("emergency_opt_out", False),
                context.get("monthly_investible_capacity"),
                context.get("total_monthly_emi_obligations"),
                context.get("risk_profile_overall"),
                context.get("review_frequency", "quarterly"),
                context.get("notify_on_drift", True),
                context.get("auto_adjust_on_income_change", False),
            )
            return {"status": "saved"}

    async def get_life_context(self, user_id: UUID) -> dict[str, Any] | None:
        """Get user life context."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
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
            return None

    async def get_goal_catalog(self) -> list[dict[str, Any]]:
        """Get goal catalog from master table."""
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT goal_category, goal_name, default_horizon, policy_linked_txn_type,
                       is_mandatory_flag, suggested_min_amount_formula, display_order
                FROM goal.goal_category_master
                WHERE active = TRUE
                ORDER BY display_order, goal_category, goal_name
                """
            )
            return [dict(row) for row in rows]

    async def create_goals(
        self, user_id: UUID, goals: list[dict[str, Any]]
    ) -> list[dict[str, Any]]:
        """Create multiple goals for a user with enhanced prioritization."""
        created_goals = []
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                repo = GoalsRepository(conn)
                goal_objects = []

                for goal_data in goals:
                    # Derive goal_type from default_horizon if not provided
                    goal_type = goal_data.get("goal_type")
                    if not goal_type:
                        # Get default_horizon from catalog
                        catalog_row = await conn.fetchrow(
                            """
                            SELECT default_horizon
                            FROM goal.goal_category_master
                            WHERE goal_category = $1 AND goal_name = $2
                            """,
                            goal_data["goal_category"],
                            goal_data["goal_name"],
                        )
                        if catalog_row:
                            horizon = catalog_row["default_horizon"]
                            if horizon == "short_term":
                                goal_type = "short_term"
                            elif horizon == "medium_term":
                                goal_type = "medium_term"
                            elif horizon == "long_term":
                                goal_type = "long_term"
                            else:
                                goal_type = "medium_term"  # default
                        else:
                            goal_type = "medium_term"

                    # Derive target_date if not provided
                    target_date = goal_data.get("target_date")
                    if target_date:
                        # Convert string to date if needed
                        if isinstance(target_date, str):
                            target_date = datetime.fromisoformat(target_date).date()
                    else:
                        if goal_type == "short_term":
                            target_date = date.today() + timedelta(days=365)
                        elif goal_type == "medium_term":
                            target_date = date.today() + timedelta(days=1095)  # 3 years
                        elif goal_type == "long_term":
                            target_date = date.today() + timedelta(days=2555)  # 7 years
                        else:
                            target_date = date.today() + timedelta(days=1095)

                    # Check if goal is completed
                    current_savings = goal_data.get("current_savings", 0.0)
                    estimated_cost = goal_data["estimated_cost"]
                    status = "completed" if current_savings >= estimated_cost else "active"

                    # Prepare goal data with enhanced fields
                    goal_create_data = {
                        "goal_category": goal_data["goal_category"],
                        "goal_name": goal_data["goal_name"],
                        "goal_type": goal_type,
                        "estimated_cost": estimated_cost,
                        "target_date": target_date,
                        "current_savings": current_savings,
                        "importance": goal_data.get("importance"),
                        "status": status,
                        "notes": goal_data.get("notes"),
                        "is_must_have": goal_data.get("is_must_have", True),
                        "timeline_flexibility": goal_data.get("timeline_flexibility"),
                        "risk_profile_for_goal": goal_data.get("risk_profile_for_goal"),
                    }

                    # Create goal using repository
                    created_goal = await repo.create_goal(user_id, goal_create_data)
                    goal_objects.append(created_goal)

                # Use GoalPlanner to assign priority ranks
                goal_dicts = [
                    {
                        "goal_id": g["goal_id"],
                        "importance": g.get("importance"),
                        "is_must_have": g.get("is_must_have", True),
                        "timeline_flexibility": g.get("timeline_flexibility"),
                        "target_date": g.get("target_date"),
                    }
                    for g in goal_objects
                ]
                GoalPlanner.assign_priority_ranks(goal_dicts)

                # Update priority ranks in database
                for goal_dict in goal_dicts:
                    await repo.update_goal(
                        user_id,
                        UUID(str(goal_dict["goal_id"])),
                        {"priority_rank": goal_dict["priority_rank"]},
                    )
                    created_goals.append(
                        {
                            "goal_id": str(goal_dict["goal_id"]),
                            "priority_rank": goal_dict["priority_rank"],
                        }
                    )

        return created_goals

    async def _recompute_priority_ranks(self, conn: asyncpg.Connection, user_id: UUID) -> None:
        """Recompute priority ranks for all user goals."""
        # Get all active goals with their computed scores
        goals = await conn.fetch(
            """
            SELECT goal_id, priority_rank
            FROM goal.user_goals_master
            WHERE user_id = $1 AND status = 'active'
            ORDER BY priority_rank ASC, target_date ASC NULLS LAST
            """,
            user_id,
        )

        # Assign sequential ranks (1, 2, 3...)
        for idx, goal in enumerate(goals, start=1):
            await conn.execute(
                """
                UPDATE goal.user_goals_master
                SET priority_rank = $1
                WHERE goal_id = $2
                """,
                idx,
                goal["goal_id"],
            )

    async def get_user_goals(self, user_id: UUID) -> list[dict[str, Any]]:
        """Get all active goals for a user."""
        async with self.pool.acquire() as conn:
            # Check if enhanced columns exist
            try:
                rows = await conn.fetch(
                    """
                    SELECT goal_id, goal_category, goal_name, goal_type, linked_txn_type,
                           estimated_cost, target_date, current_savings, importance,
                           priority_rank, status, notes, is_must_have, timeline_flexibility,
                           risk_profile_for_goal, created_at, updated_at
                    FROM goal.user_goals_master
                    WHERE user_id = $1 AND status != 'cancelled'
                    ORDER BY priority_rank ASC NULLS LAST, target_date ASC NULLS LAST
                    """,
                    user_id,
                )
            except Exception:
                # Fallback if enhanced columns don't exist yet
                rows = await conn.fetch(
                    """
                    SELECT goal_id, goal_category, goal_name, goal_type, linked_txn_type,
                           estimated_cost, target_date, current_savings, importance,
                           priority_rank, status, notes, created_at, updated_at
                    FROM goal.user_goals_master
                    WHERE user_id = $1 AND status != 'cancelled'
                    ORDER BY priority_rank ASC NULLS LAST, target_date ASC NULLS LAST
                    """,
                    user_id,
                )
            
            result = []
            for row in rows:
                goal_dict = dict(row)
                # Add defaults for missing columns if they were not selected in fallback
                if "is_must_have" not in goal_dict:
                    goal_dict["is_must_have"] = True
                if "timeline_flexibility" not in goal_dict:
                    goal_dict["timeline_flexibility"] = None
                if "risk_profile_for_goal" not in goal_dict:
                    goal_dict["risk_profile_for_goal"] = None
                
                result.append({
                    **goal_dict,
                    "goal_id": str(goal_dict["goal_id"]),
                    "created_at": goal_dict["created_at"].isoformat() if goal_dict.get("created_at") else None,
                    "updated_at": goal_dict["updated_at"].isoformat() if goal_dict.get("updated_at") else None,
                })
            
            return result

    async def get_user_goal(self, user_id: UUID, goal_id: UUID) -> dict[str, Any] | None:
        """Get a single goal by ID for a user."""
        async with self.pool.acquire() as conn:
            repo = GoalsRepository(conn)
            goal = await repo.get_goal(user_id, goal_id)
            if goal:
                return {
                    **goal,
                    "goal_id": str(goal["goal_id"]),
                    "created_at": goal["created_at"].isoformat() if goal.get("created_at") else None,
                    "updated_at": goal["updated_at"].isoformat() if goal.get("updated_at") else None,
                }
            return None

    async def update_goal(
        self, user_id: UUID, goal_id: UUID, updates: dict[str, Any]
    ) -> dict[str, Any]:
        """Update a goal using repository."""
        async with self.pool.acquire() as conn:
            repo = GoalsRepository(conn)

            # Check ownership
            existing_goal = await repo.get_goal(user_id, goal_id)
            if not existing_goal:
                raise ValueError("Goal not found or access denied")

            # Check if goal should be marked as completed
            if "current_savings" in updates or "estimated_cost" in updates:
                new_savings = updates.get("current_savings", existing_goal.get("current_savings", 0.0))
                new_cost = updates.get("estimated_cost", existing_goal.get("estimated_cost", 0.0))
                if new_savings >= new_cost:
                    updates["status"] = "completed"
                elif existing_goal.get("current_savings", 0.0) >= existing_goal.get("estimated_cost", 0.0):
                    # Was completed, but now might not be
                    updates["status"] = "active"

            # Update goal
            updated_goal = await repo.update_goal(user_id, goal_id, updates)
            if not updated_goal:
                raise ValueError("Failed to update goal")

            # Recompute priority ranks if importance or other priority-affecting fields changed
            if any(key in updates for key in ["importance", "is_must_have", "timeline_flexibility"]):
                all_goals = await repo.list_goals(user_id)
                goal_dicts = [
                    {
                        "goal_id": g["goal_id"],
                        "importance": g.get("importance"),
                        "is_must_have": g.get("is_must_have", True),
                        "timeline_flexibility": g.get("timeline_flexibility"),
                        "target_date": g.get("target_date"),
                    }
                    for g in all_goals
                ]
                GoalPlanner.assign_priority_ranks(goal_dicts)

                # Update priority ranks
                for goal_dict in goal_dicts:
                    await repo.update_goal(
                        user_id,
                        UUID(str(goal_dict["goal_id"])),
                        {"priority_rank": goal_dict["priority_rank"]},
                    )

            # Return updated goal
            final_goal = await repo.get_goal(user_id, goal_id)
            if final_goal:
                return {
                    **final_goal,
                    "goal_id": str(final_goal["goal_id"]),
                    "created_at": final_goal["created_at"].isoformat() if final_goal.get("created_at") else None,
                    "updated_at": final_goal["updated_at"].isoformat() if final_goal.get("updated_at") else None,
                }
            raise ValueError("Failed to retrieve updated goal")

    async def delete_goal(self, user_id: UUID, goal_id: UUID) -> dict[str, Any]:
        """Soft delete a goal (set status to cancelled)."""
        async with self.pool.acquire() as conn:
            # Check ownership
            owner = await conn.fetchval(
                """
                SELECT user_id FROM goal.user_goals_master WHERE goal_id = $1
                """,
                goal_id,
            )
            if owner != user_id:
                raise ValueError("Goal not found or access denied")

            await conn.execute(
                """
                UPDATE goal.user_goals_master
                SET status = 'cancelled', updated_at = NOW()
                WHERE goal_id = $1
                """,
                goal_id,
            )
            return {"status": "deleted", "goal_id": str(goal_id)}

    async def get_recommended_goals(
        self, user_id: UUID, transaction_data: dict[str, Any] | None = None
    ) -> list[dict[str, Any]]:
        """Get recommended goals based on life context and transaction patterns."""
        async with self.pool.acquire() as conn:
            # Get life context
            context = await self.get_life_context(user_id)

            # Get all goals from catalog
            all_goals = await self.get_goal_catalog()

            recommended = []

            # Emergency fund is always recommended (unless opted out)
            if context and not context.get("emergency_opt_out"):
                emergency_goal = next(
                    (g for g in all_goals if g["goal_category"] == "Emergency"), None
                )
                if emergency_goal:
                    recommended.append(emergency_goal)

            # Insurance goals for users with dependents
            if context:
                if context.get("dependents_spouse") or context.get("dependents_children_count", 0) > 0:
                    insurance_goals = [
                        g for g in all_goals if g["goal_category"] == "Insurance"
                    ]
                    recommended.extend(insurance_goals)

            # Debt paydown if there are credit card transactions
            if transaction_data:
                # This would analyze transaction patterns
                # For now, we'll recommend debt paydown for most users
                debt_goals = [g for g in all_goals if g["goal_category"] == "Debt"]
                if debt_goals:
                    recommended.append(debt_goals[0])

            # Remove duplicates while preserving order
            seen = set()
            unique_recommended = []
            for goal in recommended:
                key = (goal["goal_category"], goal["goal_name"])
                if key not in seen:
                    seen.add(key)
                    unique_recommended.append(goal)

            return unique_recommended

    async def get_goals_progress(self, user_id: UUID) -> list[dict[str, Any]]:
        """Get progress for all active goals with enhanced projections using GoalPlanner."""
        async with self.pool.acquire() as conn:
            try:
                # Get life context for planning
                context = await self.get_life_context(user_id)
                if not context:
                    # Use default context if not available
                    context = {
                        "monthly_investible_capacity": 10000.0,
                        "risk_profile_overall": "balanced",
                    }

                # Get all active goals
                repo = GoalsRepository(conn)
                goals = await repo.list_goals(user_id)
                active_goals = [g for g in goals if g.get("status") == "active"]

                if not active_goals:
                    return []

                # Use GoalPlanner to build monthly plan and get projections
                planned = GoalPlanner.build_monthly_plan(context, active_goals)

                # Create a mapping of goal_id to planned goal
                planned_map = {pg.goal_id: pg for pg in planned}

                # Check if goalcompass schema exists for milestones
                schema_exists = await conn.fetchval(
                    """
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.schemata 
                        WHERE schema_name = 'goalcompass'
                    )
                    """
                )
                
                # Build progress items using planner projections
                goal_progress = []
                for goal in active_goals:
                    goal_id_str = str(goal["goal_id"])
                    planned_goal = planned_map.get(goal_id_str)

                    # Calculate progress using planner
                    progress_pct = GoalPlanner.compute_progress_pct(goal)
                    milestones = GoalPlanner.compute_milestones(progress_pct)

                    # Use planner projection if available, otherwise use target_date
                    projected_date = None
                    if planned_goal and planned_goal.projected_completion_date:
                        projected_date = planned_goal.projected_completion_date.isoformat()
                    elif goal.get("target_date"):
                        target_date = goal["target_date"]
                        if isinstance(target_date, str):
                            projected_date = target_date
                        else:
                            projected_date = target_date.isoformat()

                    # Try to get milestones from goalcompass if available
                    if schema_exists:
                        try:
                            milestone_table_exists = await conn.fetchval(
                                """
                                SELECT EXISTS (
                                    SELECT 1 FROM information_schema.tables 
                                    WHERE table_schema = 'goalcompass' 
                                    AND table_name = 'user_goal_milestone_status'
                                )
                                """
                            )
                            
                            if milestone_table_exists:
                                milestone_rows = await conn.fetch(
                                    """
                                    SELECT DISTINCT m.threshold_pct::INTEGER AS milestone_pct
                                    FROM goalcompass.user_goal_milestone_status ugms
                                    JOIN goalcompass.goal_milestone_master m ON ugms.milestone_id = m.milestone_id
                                    WHERE ugms.user_id = $1 
                                      AND ugms.goal_id = $2
                                      AND ugms.achieved_flag = TRUE
                                    ORDER BY m.threshold_pct
                                    """,
                                    user_id,
                                    UUID(goal_id_str),
                                )
                                if milestone_rows:
                                    milestones = [int(m["milestone_pct"]) for m in milestone_rows]
                        except Exception as milestone_error:
                            logger.debug(f"Could not fetch milestones for goal {goal_id_str}: {milestone_error}")

                    current_savings = goal.get("current_savings", 0.0)
                    estimated_cost = goal.get("estimated_cost", 0.0)
                    remaining = max(estimated_cost - current_savings, 0.0)

                    goal_progress.append({
                        "goal_id": goal_id_str,
                        "goal_name": goal.get("goal_name", ""),
                        "progress_pct": progress_pct,
                        "current_savings_close": float(current_savings),
                        "remaining_amount": remaining,
                        "projected_completion_date": projected_date,
                        "milestones": milestones,
                    })

                return goal_progress
            except Exception as e:
                logger.error(f"Error in get_goals_progress for user {user_id}: {e}", exc_info=True)
                raise

