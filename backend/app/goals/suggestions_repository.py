"""Repository for goal suggestions using asyncpg."""

from typing import Any
from uuid import UUID

import asyncpg


class GoalSuggestionsRepository:
    """Repository for goal suggestions database operations."""

    def __init__(self, conn: asyncpg.Connection):
        self.conn = conn

    async def insert_suggestion(
        self,
        user_id: UUID,
        goal_id: UUID | None,
        suggestion_type: str,
        title: str,
        description: str,
        action_payload: dict[str, Any] | None = None,
    ) -> None:
        """Insert a new goal suggestion."""
        await self.conn.execute(
            """
            INSERT INTO goal.goal_suggestions
                (user_id, goal_id, suggestion_type, title, description, action_payload)
            VALUES
                ($1, $2, $3, $4, $5, $6)
            """,
            user_id,
            goal_id,
            suggestion_type,
            title,
            description,
            action_payload or {},
        )

    async def list_open_suggestions(self, user_id: UUID) -> list[dict[str, Any]]:
        """List open suggestions for a user."""
        rows = await self.conn.fetch(
            """
            SELECT id, goal_id, suggestion_type, title, description, action_payload,
                   status, created_at, updated_at
            FROM goal.goal_suggestions
            WHERE user_id = $1 AND status = 'open'
            ORDER BY created_at DESC
            """,
            user_id,
        )
        return [dict(row) for row in rows]

    async def update_status(
        self, user_id: UUID, suggestion_id: UUID, new_status: str
    ) -> None:
        """Update suggestion status."""
        await self.conn.execute(
            """
            UPDATE goal.goal_suggestions
            SET status = $1, updated_at = now()
            WHERE id = $2 AND user_id = $3
            """,
            new_status,
            suggestion_id,
            user_id,
        )

