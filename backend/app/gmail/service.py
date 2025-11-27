from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from asyncpg import Pool

from app.gmail.models import GmailJobStatus


class GmailService:
    def __init__(self, pool: Pool) -> None:
        self._pool = pool

    async def upsert_connection(
        self,
        user_id: str,
        access_token: str,
        refresh_token: str,
        expires_in: int,
        email_address: str | None = None,
    ) -> None:
        token_expiry = datetime.utcnow() + timedelta(seconds=expires_in)
        query = """
        INSERT INTO spendsense.gmail_connection (user_id, access_token, refresh_token, token_expiry, email_address)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (user_id) DO UPDATE SET
            access_token = EXCLUDED.access_token,
            refresh_token = EXCLUDED.refresh_token,
            token_expiry = EXCLUDED.token_expiry,
            email_address = COALESCE(EXCLUDED.email_address, spendsense.gmail_connection.email_address),
            updated_at = NOW()
        """
        await self._pool.execute(query, user_id, access_token, refresh_token, token_expiry, email_address)

    async def get_connection(self, user_id: str) -> dict[str, Any] | None:
        query = """
        SELECT user_id, access_token, refresh_token, token_expiry
        FROM spendsense.gmail_connection
        WHERE user_id = $1
        """
        row = await self._pool.fetchrow(query, user_id)
        if not row:
            return None
        return dict(row)

    async def create_sync_job(self, user_id: str, status: str = "queued") -> str:
        query = """
        INSERT INTO spendsense.gmail_sync_job (user_id, status, progress)
        VALUES ($1, $2, 0)
        RETURNING job_id
        """
        job_id = await self._pool.fetchval(query, user_id, status)
        return str(job_id)

    async def update_job(
        self,
        job_id: str,
        status: str | None = None,
        progress: int | None = None,
        error: str | None = None,
    ) -> None:
        fields: list[str] = []
        values: list[Any] = []
        if status is not None:
            fields.append("status = ${}".format(len(values) + 1))
            values.append(status)
        if progress is not None:
            fields.append("progress = ${}".format(len(values) + 1))
            values.append(progress)
        if error is not None:
            fields.append("error = ${}".format(len(values) + 1))
            values.append(error)

        if not fields:
            return

        set_clause = ", ".join(fields) + ", updated_at = NOW()"
        query = f"UPDATE spendsense.gmail_sync_job SET {set_clause} WHERE job_id = ${len(values) + 1}"
        values.append(job_id)
        await self._pool.execute(query, *values)

    async def get_latest_job(self, user_id: str) -> GmailJobStatus | None:
        query = """
        SELECT job_id, status, progress, error, created_at, updated_at
        FROM spendsense.gmail_sync_job
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        """
        row = await self._pool.fetchrow(query, user_id)
        if not row:
            return None
        return GmailJobStatus(
            job_id=str(row["job_id"]),
            status=row["status"],
            progress=row["progress"],
            error=row["error"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )

    async def upsert_watch(
        self,
        user_id: str,
        watch_id: str,
        history_id: str,
        topic_name: str,
        expires_at: datetime,
    ) -> None:
        query = """
        INSERT INTO spendsense.gmail_watch (user_id, watch_id, history_id, topic_name, expires_at)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (user_id) DO UPDATE SET
            watch_id = EXCLUDED.watch_id,
            history_id = EXCLUDED.history_id,
            topic_name = EXCLUDED.topic_name,
            expires_at = EXCLUDED.expires_at,
            updated_at = NOW()
        """
        await self._pool.execute(query, user_id, watch_id, history_id, topic_name, expires_at)

    async def get_watch(self, user_id: str) -> dict[str, Any] | None:
        query = """
        SELECT user_id, watch_id, history_id, topic_name, expires_at
        FROM spendsense.gmail_watch
        WHERE user_id = $1
        """
        row = await self._pool.fetchrow(query, user_id)
        if not row:
            return None
        return dict(row)

    async def delete_watch(self, user_id: str) -> None:
        query = "DELETE FROM spendsense.gmail_watch WHERE user_id = $1"
        await self._pool.execute(query, user_id)


