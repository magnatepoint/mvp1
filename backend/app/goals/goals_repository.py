"""Goals repository for DB operations (asyncpg)."""

from typing import Any
from uuid import UUID

import asyncpg


class GoalsRepository:
    """Repository for goal database operations using asyncpg."""

    def __init__(self, conn: asyncpg.Connection):
        self.conn = conn

    async def create_goal(self, user_id: UUID, goal_data: dict[str, Any]) -> dict[str, Any]:
        """Create a new goal and return it."""
        try:
            goal_id = await self.conn.fetchval(
                """
                INSERT INTO goal.user_goals_master (
                    user_id, goal_category, goal_name, goal_type,
                    estimated_cost, target_date, current_savings,
                    importance, status, notes, is_must_have,
                    timeline_flexibility, risk_profile_for_goal
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
                RETURNING goal_id
                """,
                user_id,
                goal_data["goal_category"],
                goal_data["goal_name"],
                goal_data.get("goal_type", "user_defined"),
                goal_data["estimated_cost"],
                goal_data.get("target_date"),
                goal_data.get("current_savings", 0.0),
                goal_data.get("importance"),
                goal_data.get("status", "active"),
                goal_data.get("notes"),
                goal_data.get("is_must_have", True),
                goal_data.get("timeline_flexibility"),
                goal_data.get("risk_profile_for_goal"),
            )
        except Exception:
            # Fallback if enhanced columns don't exist yet
            goal_id = await self.conn.fetchval(
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
                goal_data.get("goal_type", "user_defined"),
                goal_data["estimated_cost"],
                goal_data.get("target_date"),
                goal_data.get("current_savings", 0.0),
                goal_data.get("importance"),
                goal_data.get("status", "active"),
                goal_data.get("notes"),
            )
        return await self.get_goal(user_id, goal_id)

    async def get_goal(self, user_id: UUID, goal_id: UUID) -> dict[str, Any] | None:
        """Get a single goal by ID."""
        try:
            row = await self.conn.fetchrow(
                """
                SELECT goal_id, goal_category, goal_name, goal_type, linked_txn_type,
                       estimated_cost, target_date, current_savings, importance,
                       priority_rank, status, notes, is_must_have, timeline_flexibility,
                       risk_profile_for_goal, created_at, updated_at
                FROM goal.user_goals_master
                WHERE user_id = $1 AND goal_id = $2
                """,
                user_id,
                goal_id,
            )
        except Exception:
            # Fallback if enhanced columns don't exist yet
            row = await self.conn.fetchrow(
                """
                SELECT goal_id, goal_category, goal_name, goal_type, linked_txn_type,
                       estimated_cost, target_date, current_savings, importance,
                       priority_rank, status, notes, created_at, updated_at
                FROM goal.user_goals_master
                WHERE user_id = $1 AND goal_id = $2
                """,
                user_id,
                goal_id,
            )
        
        if row:
            result = dict(row)
            # Add defaults for missing columns
            if "is_must_have" not in result:
                result["is_must_have"] = True
            if "timeline_flexibility" not in result:
                result["timeline_flexibility"] = None
            if "risk_profile_for_goal" not in result:
                result["risk_profile_for_goal"] = None
            return result
        return None

    async def list_goals(self, user_id: UUID) -> list[dict[str, Any]]:
        """List all goals for a user, ordered by priority."""
        try:
            rows = await self.conn.fetch(
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
            rows = await self.conn.fetch(
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
            # Add defaults for missing columns
            if "is_must_have" not in goal_dict:
                goal_dict["is_must_have"] = True
            if "timeline_flexibility" not in goal_dict:
                goal_dict["timeline_flexibility"] = None
            if "risk_profile_for_goal" not in goal_dict:
                goal_dict["risk_profile_for_goal"] = None
            result.append(goal_dict)
        return result

    async def update_goal(
        self, user_id: UUID, goal_id: UUID, updates: dict[str, Any]
    ) -> dict[str, Any] | None:
        """Update a goal and return the updated goal."""
        # Check which columns exist
        enhanced_fields = ["is_must_have", "timeline_flexibility", "risk_profile_for_goal"]
        has_enhanced_fields = False
        try:
            await self.conn.fetchval(
                "SELECT is_must_have FROM goal.user_goals_master WHERE user_id = $1 LIMIT 1",
                user_id,
            )
            has_enhanced_fields = True
        except Exception:
            has_enhanced_fields = False

        # Build update query dynamically
        update_fields = []
        params = []
        param_idx = 1

        field_mapping = {
            "estimated_cost": "estimated_cost",
            "target_date": "target_date",
            "current_savings": "current_savings",
            "importance": "importance",
            "notes": "notes",
            "priority_rank": "priority_rank",
            "status": "status",
            "drift_amount": "drift_amount",
            "drift_pct": "drift_pct",
            "last_contribution_at": "last_contribution_at",
            "last_txn_id": "last_txn_id",
        }
        
        # Only include enhanced fields if they exist
        if has_enhanced_fields:
            field_mapping.update({
                "is_must_have": "is_must_have",
                "timeline_flexibility": "timeline_flexibility",
                "risk_profile_for_goal": "risk_profile_for_goal",
            })
        
        # Add drift fields (check if they exist)
        try:
            await self.conn.fetchval(
                "SELECT drift_amount FROM goal.user_goals_master WHERE user_id = $1 LIMIT 1",
                user_id,
            )
            field_mapping.update({
                "drift_amount": "drift_amount",
                "drift_pct": "drift_pct",
                "last_contribution_at": "last_contribution_at",
                "last_txn_id": "last_txn_id",
            })
        except Exception:
            pass  # Drift fields don't exist yet

        for key, db_field in field_mapping.items():
            if key in updates:
                update_fields.append(f"{db_field} = ${param_idx}")
                params.append(updates[key])
                param_idx += 1

        if not update_fields:
            return await self.get_goal(user_id, goal_id)

        update_fields.append("updated_at = NOW()")
        params.extend([goal_id, user_id])

        await self.conn.execute(
            f"""
            UPDATE goal.user_goals_master
            SET {', '.join(update_fields)}
            WHERE goal_id = ${param_idx} AND user_id = ${param_idx + 1}
            """,
            *params,
        )

        return await self.get_goal(user_id, goal_id)

    async def delete_goal(self, user_id: UUID, goal_id: UUID) -> bool:
        """Soft delete a goal (set status to cancelled)."""
        result = await self.conn.execute(
            """
            UPDATE goal.user_goals_master
            SET status = 'cancelled', updated_at = NOW()
            WHERE goal_id = $1 AND user_id = $2
            """,
            goal_id,
            user_id,
        )
        return result == "UPDATE 1"

    async def update_priority_ranks(
        self, user_id: UUID, goal_ranks: list[tuple[UUID, int]]
    ) -> None:
        """Update priority ranks for multiple goals."""
        for goal_id, rank in goal_ranks:
            await self.conn.execute(
                """
                UPDATE goal.user_goals_master
                SET priority_rank = $1, updated_at = NOW()
                WHERE goal_id = $2 AND user_id = $3
                """,
                rank,
                goal_id,
                user_id,
            )

