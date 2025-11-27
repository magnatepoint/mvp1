from fastapi import Depends, Request

from asyncpg import Pool


def get_db_pool(request: Request) -> Pool:
    pool = getattr(request.app.state, "db_pool", None)
    if pool is None:
        raise RuntimeError("Database pool is not initialized")
    return pool

