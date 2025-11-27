"""Celery tasks for ML model training."""

import asyncio
import logging

import asyncpg

from app.celery_app import celery_app
from app.core.config import get_settings
from .trainer import apply_merchant_feedback, train_ml_model

logger = logging.getLogger(__name__)
settings = get_settings()


@celery_app.task(name="spendsense.ml.retrain_user_model", bind=True, max_retries=3)
def retrain_user_model_task(self, user_id: str) -> dict[str, any]:
    """Retrain ML model for a specific user based on their feedback."""
    try:
        # Run async function in sync context
        result = asyncio.run(_retrain_user_model(user_id))
        logger.info(f"Retrained ML model for user {user_id}: {result}")
        return result
    except Exception as exc:
        logger.error(f"Failed to retrain model for user {user_id}: {exc}")
        raise self.retry(exc=exc, countdown=60 * (self.request.retries + 1))


async def _retrain_user_model(user_id: str) -> dict[str, any]:
    """Async helper for retraining user model."""
    conn = await asyncpg.connect(
        str(settings.postgres_dsn),
        statement_cache_size=0,
        timeout=30,
    )
    try:
        return await train_ml_model(conn, user_id=user_id, model_type="combined")
    finally:
        await conn.close()


@celery_app.task(name="spendsense.ml.retrain_global_model", bind=True, max_retries=3)
def retrain_global_model_task(self) -> dict[str, any]:
    """Retrain global ML model from all users' data."""
    try:
        # Run async function in sync context
        result = asyncio.run(_retrain_global_model())
        logger.info(f"Retrained global ML model: {result}")
        return result
    except Exception as exc:
        logger.error(f"Failed to retrain global model: {exc}")
        raise self.retry(exc=exc, countdown=300 * (self.request.retries + 1))


async def _retrain_global_model() -> dict[str, any]:
    """Async helper for retraining global model."""
    conn = await asyncpg.connect(
        str(settings.postgres_dsn),
        statement_cache_size=0,
        timeout=30,
    )
    try:
        return await train_ml_model(conn, user_id=None, model_type="combined")
    finally:
        await conn.close()


@celery_app.task(name="spendsense.ml.apply_merchant_feedback", bind=True, max_retries=3)
def apply_merchant_feedback_task(self) -> dict[str, any]:
    """Process merchant/channel feedback into alias mappings."""
    try:
        result = asyncio.run(_apply_merchant_feedback())
        logger.info(f"Applied merchant feedback: {result}")
        return result
    except Exception as exc:
        logger.error(f"Failed to apply merchant feedback: {exc}")
        raise self.retry(exc=exc, countdown=120 * (self.request.retries + 1))


async def _apply_merchant_feedback() -> dict[str, any]:
    conn = await asyncpg.connect(
        str(settings.postgres_dsn),
        statement_cache_size=0,
        timeout=30,
    )
    try:
        return await apply_merchant_feedback(conn)
    finally:
        await conn.close()

