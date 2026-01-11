"""Repository for goal signals using asyncpg."""

from typing import Any
from uuid import UUID

import asyncpg


class GoalSignalsRepository:
    """Repository for goal signals database operations."""

    def __init__(self, conn: asyncpg.Connection):
        self.conn = conn

    async def insert_signal(
        self,
        user_id: UUID,
        goal_id: UUID | None,
        signal_type: str,
        severity: str,
        message: str,
        meta: dict[str, Any] | None = None,
    ) -> None:
        """Insert a new goal signal."""
        await self.conn.execute(
            """
            INSERT INTO goal.goal_signals
                (user_id, goal_id, signal_type, severity, message, meta)
            VALUES
                ($1, $2, $3, $4, $5, $6)
            """,
            user_id,
            goal_id,
            signal_type,
            severity,
            message,
            meta or {},
        )

    async def get_recent_signals(self, user_id: UUID, limit: int = 20) -> list[dict[str, Any]]:
        """Get recent signals for a user."""
        rows = await self.conn.fetch(
            """
            SELECT id, goal_id, signal_type, severity, message, meta, created_at
            FROM goal.goal_signals
            WHERE user_id = $1 AND resolved_at IS NULL
            ORDER BY created_at DESC
            LIMIT $2
            """,
            user_id,
            limit,
        )
        return [dict(row) for row in rows]

    async def resolve_signal(self, signal_id: UUID, user_id: UUID) -> None:
        """Mark a signal as resolved."""
        await self.conn.execute(
            """
            UPDATE goal.goal_signals
            SET resolved_at = now()
            WHERE id = $1 AND user_id = $2
            """,
            signal_id,
            user_id,
        )

