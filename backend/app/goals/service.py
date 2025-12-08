"""Service layer for Goals module."""

import logging
from datetime import date, datetime, timedelta
from typing import Any
from uuid import UUID

import asyncpg

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
                    region_code, emergency_opt_out
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
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
                context["emergency_opt_out"],
            )
            return {"status": "saved"}

    async def get_life_context(self, user_id: UUID) -> dict[str, Any] | None:
        """Get user life context."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT age_band, dependents_spouse, dependents_children_count,
                       dependents_parents_care, housing, employment, income_regularity,
                       region_code, emergency_opt_out
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
        """Create multiple goals for a user."""
        created_goals = []
        async with self.pool.acquire() as conn:
            async with conn.transaction():
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

                    # Insert goal (triggers will auto-compute linked_txn_type and priority_rank)
                    goal_id = await conn.fetchval(
                        """
                        INSERT INTO goal.user_goals_master (
                            user_id, goal_category, goal_name, goal_type,
                            estimated_cost, target_date, current_savings,
                            importance, status, notes
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                        RETURNING goal_id
                        """,
                        user_id,
                        goal_data["goal_category"],
                        goal_data["goal_name"],
                        goal_type,
                        estimated_cost,
                        target_date,
                        current_savings,
                        goal_data.get("importance"),
                        status,
                        goal_data.get("notes"),
                    )

                    # Get priority_rank after insert (computed by trigger)
                    priority_rank = await conn.fetchval(
                        """
                        SELECT priority_rank
                        FROM goal.user_goals_master
                        WHERE goal_id = $1
                        """,
                        goal_id,
                    )

                    created_goals.append(
                        {"goal_id": str(goal_id), "priority_rank": priority_rank}
                    )

                # Recompute all priority ranks for user (in case of ties)
                await self._recompute_priority_ranks(conn, user_id)

                # Update priority_ranks in created_goals
                for goal_info in created_goals:
                    goal_id = UUID(goal_info["goal_id"])
                    priority_rank = await conn.fetchval(
                        """
                        SELECT priority_rank
                        FROM goal.user_goals_master
                        WHERE goal_id = $1
                        """,
                        goal_id,
                    )
                    goal_info["priority_rank"] = priority_rank

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
            return [
                {
                    **dict(row),
                    "goal_id": str(row["goal_id"]),
                    "created_at": row["created_at"].isoformat() if row["created_at"] else None,
                    "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
                }
                for row in rows
            ]

    async def update_goal(
        self, user_id: UUID, goal_id: UUID, updates: dict[str, Any]
    ) -> dict[str, Any]:
        """Update a goal."""
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

            # Build update query dynamically
            update_fields = []
            params = []
            param_idx = 1

            if "estimated_cost" in updates:
                update_fields.append(f"estimated_cost = ${param_idx}")
                params.append(updates["estimated_cost"])
                param_idx += 1

            if "target_date" in updates:
                update_fields.append(f"target_date = ${param_idx}")
                params.append(updates["target_date"])
                param_idx += 1

            if "current_savings" in updates:
                update_fields.append(f"current_savings = ${param_idx}")
                params.append(updates["current_savings"])
                param_idx += 1

            if "importance" in updates:
                update_fields.append(f"importance = ${param_idx}")
                params.append(updates["importance"])
                param_idx += 1

            if "notes" in updates:
                update_fields.append(f"notes = ${param_idx}")
                params.append(updates["notes"])
                param_idx += 1

            if not update_fields:
                raise ValueError("No fields to update")

            # Check if goal should be marked as completed
            if "current_savings" in updates or "estimated_cost" in updates:
                # Get current values
                current = await conn.fetchrow(
                    """
                    SELECT current_savings, estimated_cost
                    FROM goal.user_goals_master
                    WHERE goal_id = $1
                    """,
                    goal_id,
                )
                if current:
                    new_savings = updates.get("current_savings", current["current_savings"])
                    new_cost = updates.get("estimated_cost", current["estimated_cost"])
                    if new_savings >= new_cost:
                        update_fields.append("status = 'completed'")
                    elif current["current_savings"] >= current["estimated_cost"]:
                        # Was completed, but now might not be
                        update_fields.append("status = 'active'")

            params.append(goal_id)
            await conn.execute(
                f"""
                UPDATE goal.user_goals_master
                SET {', '.join(update_fields)}, updated_at = NOW()
                WHERE goal_id = ${param_idx}
                """,
                *params,
            )

            # Recompute priority ranks
            await self._recompute_priority_ranks(conn, user_id)

            # Return updated goal
            row = await conn.fetchrow(
                """
                SELECT goal_id, goal_category, goal_name, goal_type, linked_txn_type,
                       estimated_cost, target_date, current_savings, importance,
                       priority_rank, status, notes, created_at, updated_at
                FROM goal.user_goals_master
                WHERE goal_id = $1
                """,
                goal_id,
            )
            return {
                **dict(row),
                "goal_id": str(row["goal_id"]),
                "created_at": row["created_at"].isoformat() if row["created_at"] else None,
                "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
            }

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
        """Get progress for all active goals from latest snapshot."""
        async with self.pool.acquire() as conn:
            try:
                # Check if goalcompass schema exists
                schema_exists = await conn.fetchval(
                    """
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.schemata 
                        WHERE schema_name = 'goalcompass'
                    )
                    """
                )
                
                # Try to use goalcompass snapshot if available, otherwise fall back to basic goal data
                if schema_exists:
                    try:
                        # Check if goal_compass_snapshot table exists
                        table_exists = await conn.fetchval(
                            """
                            SELECT EXISTS (
                                SELECT 1 FROM information_schema.tables 
                                WHERE table_schema = 'goalcompass' 
                                AND table_name = 'goal_compass_snapshot'
                            )
                            """
                        )
                        
                        if table_exists:
                            # Use goalcompass snapshot data
                            rows = await conn.fetch(
                                """
                                SELECT 
                                    g.goal_id,
                                    g.goal_name,
                                    CASE 
                                        WHEN s.progress_pct IS NOT NULL THEN s.progress_pct
                                        WHEN g.estimated_cost > 0 THEN (g.current_savings / g.estimated_cost * 100.0)
                                        ELSE 0.0
                                    END AS progress_pct,
                                    COALESCE(s.progress_amount, g.current_savings, 0.0) AS current_savings_close,
                                    CASE 
                                        WHEN s.remaining_amount IS NOT NULL THEN s.remaining_amount
                                        WHEN g.estimated_cost > 0 THEN GREATEST(0, g.estimated_cost - COALESCE(g.current_savings, 0.0))
                                        ELSE g.estimated_cost
                                    END AS remaining_amount,
                                    CASE 
                                        WHEN s.months_remaining IS NOT NULL AND s.months_remaining > 0 THEN
                                            (CURRENT_DATE + (s.months_remaining || ' months')::INTERVAL)::DATE
                                        WHEN g.target_date IS NOT NULL THEN g.target_date
                                        ELSE NULL
                                    END AS projected_completion_date
                                FROM goal.user_goals_master g
                                LEFT JOIN LATERAL (
                                    SELECT 
                                        progress_pct,
                                        progress_amount,
                                        remaining_amount,
                                        months_remaining
                                    FROM goalcompass.goal_compass_snapshot s
                                    WHERE s.user_id = $1 AND s.goal_id = g.goal_id
                                    ORDER BY s.month DESC
                                    LIMIT 1
                                ) s ON TRUE
                                WHERE g.user_id = $1 
                                  AND g.status = 'active'
                                ORDER BY g.priority_rank ASC NULLS LAST
                                """,
                                user_id,
                            )
                        else:
                            # Fall back to basic goal data
                            rows = await conn.fetch(
                                """
                                SELECT 
                                    g.goal_id,
                                    g.goal_name,
                                    CASE 
                                        WHEN g.estimated_cost > 0 THEN (g.current_savings / g.estimated_cost * 100.0)
                                        ELSE 0.0
                                    END AS progress_pct,
                                    COALESCE(g.current_savings, 0.0) AS current_savings_close,
                                    CASE 
                                        WHEN g.estimated_cost > 0 THEN GREATEST(0, g.estimated_cost - COALESCE(g.current_savings, 0.0))
                                        ELSE g.estimated_cost
                                    END AS remaining_amount,
                                    g.target_date AS projected_completion_date
                                FROM goal.user_goals_master g
                                WHERE g.user_id = $1 
                                  AND g.status = 'active'
                                ORDER BY g.priority_rank ASC NULLS LAST
                                """,
                                user_id,
                            )
                    except Exception as schema_error:
                        logger.warning(f"Error accessing goalcompass schema, falling back to basic goal data: {schema_error}")
                        # Fall back to basic goal data
                        rows = await conn.fetch(
                            """
                            SELECT 
                                g.goal_id,
                                g.goal_name,
                                CASE 
                                    WHEN g.estimated_cost > 0 THEN (g.current_savings / g.estimated_cost * 100.0)
                                    ELSE 0.0
                                END AS progress_pct,
                                COALESCE(g.current_savings, 0.0) AS current_savings_close,
                                CASE 
                                    WHEN g.estimated_cost > 0 THEN GREATEST(0, g.estimated_cost - COALESCE(g.current_savings, 0.0))
                                    ELSE g.estimated_cost
                                END AS remaining_amount,
                                g.target_date AS projected_completion_date
                            FROM goal.user_goals_master g
                            WHERE g.user_id = $1 
                              AND g.status = 'active'
                            ORDER BY g.priority_rank ASC NULLS LAST
                            """,
                            user_id,
                        )
                else:
                    # Fall back to basic goal data if schema doesn't exist
                    rows = await conn.fetch(
                        """
                        SELECT 
                            g.goal_id,
                            g.goal_name,
                            CASE 
                                WHEN g.estimated_cost > 0 THEN (g.current_savings / g.estimated_cost * 100.0)
                                ELSE 0.0
                            END AS progress_pct,
                            COALESCE(g.current_savings, 0.0) AS current_savings_close,
                            CASE 
                                WHEN g.estimated_cost > 0 THEN GREATEST(0, g.estimated_cost - COALESCE(g.current_savings, 0.0))
                                ELSE g.estimated_cost
                            END AS remaining_amount,
                            g.target_date AS projected_completion_date
                        FROM goal.user_goals_master g
                        WHERE g.user_id = $1 
                          AND g.status = 'active'
                        ORDER BY g.priority_rank ASC NULLS LAST
                        """,
                        user_id,
                    )

                # Get milestones for each goal (handle missing tables gracefully)
                goal_progress = []
                for row in rows:
                    goal_id = row["goal_id"]
                    milestones = []
                    
                    # Try to get milestones if goalcompass tables exist
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
                                    goal_id,
                                )
                                milestones = [int(m["milestone_pct"]) for m in milestone_rows]
                        except Exception as milestone_error:
                            logger.debug(f"Could not fetch milestones for goal {goal_id}: {milestone_error}")
                            milestones = []
                    
                    # Handle date serialization
                    projected_date = None
                    if row["projected_completion_date"]:
                        if isinstance(row["projected_completion_date"], date):
                            projected_date = row["projected_completion_date"].isoformat()
                        else:
                            projected_date = str(row["projected_completion_date"])

                    goal_progress.append({
                        "goal_id": str(goal_id),
                        "goal_name": row["goal_name"],
                        "progress_pct": float(row["progress_pct"]),
                        "current_savings_close": float(row["current_savings_close"]),
                        "remaining_amount": float(row["remaining_amount"]),
                        "projected_completion_date": projected_date,
                        "milestones": milestones,
                    })

                return goal_progress
            except Exception as e:
                logger.error(f"Error in get_goals_progress for user {user_id}: {e}", exc_info=True)
                raise

