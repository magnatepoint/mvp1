from __future__ import annotations

import asyncpg


async def mark_message_started(
    conn: asyncpg.Connection,
    user_id: str,
    message_id: str,
    history_id: int,
) -> bool:
    row = await conn.fetchrow(
        """
        INSERT INTO spendsense.gmail_message (gmail_account_id, gmail_message_id, history_id)
        VALUES ($1, $2, $3)
        ON CONFLICT (gmail_account_id, gmail_message_id) DO NOTHING
        RETURNING id
        """,
        user_id,
        message_id,
        history_id,
    )
    return row is not None


async def mark_message_result(
    conn: asyncpg.Connection,
    user_id: str,
    message_id: str,
    *,
    success: bool,
    error: str | None = None,
) -> None:
    await conn.execute(
        """
        UPDATE spendsense.gmail_message
        SET success=$3, error_message=$4, processed_at=NOW()
        WHERE gmail_account_id=$1 AND gmail_message_id=$2
        """,
        user_id,
        message_id,
        success,
        error,
    )

