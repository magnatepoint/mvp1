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
    """Async helper for retraining user model with retry logic."""
    conn: asyncpg.Connection | None = None
    try:
        # Connect with retry logic
        max_retries = 3
        retry_delay = 2
        for attempt in range(max_retries):
            try:
                conn = await asyncio.wait_for(
                    asyncpg.connect(
                        str(settings.postgres_dsn),
                        statement_cache_size=0,
                        timeout=30,  # 30 second connection timeout
                    ),
                    timeout=35.0,
                )
                break
            except (asyncio.TimeoutError, OSError, Exception) as exc:
                if attempt < max_retries - 1:
                    logger.warning(f"Database connection attempt {attempt + 1} failed: {exc}. Retrying...")
                    await asyncio.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    logger.error(f"Failed to connect to database after {max_retries} attempts: {exc}")
                    raise
        
        if conn is None:
            raise RuntimeError("Failed to establish database connection")
        
        result = await train_ml_model(conn, user_id=user_id, model_type="combined")
        return result
    finally:
        if conn:
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
    """Async helper for retraining global model with retry logic."""
    conn: asyncpg.Connection | None = None
    try:
        # Connect with retry logic
        max_retries = 3
        retry_delay = 2
        for attempt in range(max_retries):
            try:
                conn = await asyncio.wait_for(
                    asyncpg.connect(
                        str(settings.postgres_dsn),
                        statement_cache_size=0,
                        timeout=30,  # 30 second connection timeout
                    ),
                    timeout=35.0,
                )
                break
            except (asyncio.TimeoutError, OSError, Exception) as exc:
                if attempt < max_retries - 1:
                    logger.warning(f"Database connection attempt {attempt + 1} failed: {exc}. Retrying...")
                    await asyncio.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    logger.error(f"Failed to connect to database after {max_retries} attempts: {exc}")
                    raise
        
        if conn is None:
            raise RuntimeError("Failed to establish database connection")
        
        result = await train_ml_model(conn, user_id=None, model_type="combined")
        return result
    finally:
        if conn:
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
    """Async helper for applying merchant feedback with retry logic."""
    conn: asyncpg.Connection | None = None
    try:
        # Connect with retry logic
        max_retries = 3
        retry_delay = 2
        for attempt in range(max_retries):
            try:
                conn = await asyncio.wait_for(
                    asyncpg.connect(
                        str(settings.postgres_dsn),
                        statement_cache_size=0,
                        timeout=30,  # 30 second connection timeout
                    ),
                    timeout=35.0,
                )
                break
            except (asyncio.TimeoutError, OSError, Exception) as exc:
                if attempt < max_retries - 1:
                    logger.warning(f"Database connection attempt {attempt + 1} failed: {exc}. Retrying...")
                    await asyncio.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    logger.error(f"Failed to connect to database after {max_retries} attempts: {exc}")
                    raise
        
        if conn is None:
            raise RuntimeError("Failed to establish database connection")
        
        result = await apply_merchant_feedback(conn)
        return result
    finally:
        if conn:
            await conn.close()


@celery_app.task(name="spendsense.ml.train_category_model", bind=True, max_retries=3)
def train_category_model_task(self) -> dict[str, any]:
    """
    Train category prediction model (TF-IDF + LogisticRegression).
    
    This trains the model used by ml_category_model.py for ML fallback
    when rule-based matching fails.
    """
    try:
        result = asyncio.run(_train_category_model())
        logger.info(f"Trained category model: {result}")
        return result
    except Exception as exc:
        logger.error(f"Failed to train category model: {exc}")
        raise self.retry(exc=exc, countdown=300 * (self.request.retries + 1))


async def _train_category_model() -> dict[str, any]:
    """Async helper for training category model."""
    import os
    import sys
    from pathlib import Path
    
    # Import the training script
    sys.path.insert(0, str(Path(__file__).parent.parent.parent))
    from app.spendsense.scripts.train_category_model import fetch_training_data, MODEL_PATH
    
    import joblib
    import numpy as np
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.preprocessing import LabelEncoder
    
    conn: asyncpg.Connection | None = None
    try:
        # Connect with retry logic
        max_retries = 3
        retry_delay = 2
        for attempt in range(max_retries):
            try:
                conn = await asyncio.wait_for(
                    asyncpg.connect(
                        str(settings.postgres_dsn),
                        statement_cache_size=0,
                        timeout=30,  # 30 second connection timeout
                    ),
                    timeout=35.0,
                )
                break
            except (asyncio.TimeoutError, OSError, Exception) as exc:
                if attempt < max_retries - 1:
                    logger.warning(f"Database connection attempt {attempt + 1} failed: {exc}. Retrying...")
                    await asyncio.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    logger.error(f"Failed to connect to database after {max_retries} attempts: {exc}")
                    raise
        
        if conn is None:
            raise RuntimeError("Failed to establish database connection")
        
        logger.info("Fetching training data...")
        texts, amounts, labels = await fetch_training_data(conn, limit=100_000)

        if len(texts) < 1000:
            return {
                "error": f"Not enough data to train model (got {len(texts)}, need at least 1000)",
                "samples": len(texts),
            }

        logger.info(f"Training on {len(texts)} transactions...")
        logger.info(f"Unique categories: {len(set(labels))}")

        # TF-IDF vectorization
        logger.info("Vectorizing text features...")
        tfidf = TfidfVectorizer(
            max_features=30000,
            ngram_range=(1, 2),
            min_df=2,
            stop_words="english",
        )
        X_text = tfidf.fit_transform(texts)

        # Combine with amount feature
        logger.info("Combining features...")
        amt_arr = np.array(amounts).reshape(-1, 1)
        X = np.hstack([X_text.toarray(), amt_arr])

        # Encode labels
        logger.info("Encoding labels...")
        le = LabelEncoder()
        y = le.fit_transform(labels)

        # Train model
        logger.info("Training LogisticRegression model...")
        clf = LogisticRegression(
            multi_class="multinomial",
            max_iter=500,
            n_jobs=-1,
            random_state=42,
        )
        clf.fit(X, y)

        # Save model bundle
        os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
        bundle = {
            "vectorizer": tfidf,
            "model": clf,
            "label_encoder": le,
        }
        joblib.dump(bundle, MODEL_PATH)

        return {
            "status": "success",
            "model_path": MODEL_PATH,
            "samples": len(texts),
            "categories": len(le.classes_),
            "features": X.shape[1],
        }
    except ImportError as e:
        return {
            "error": f"ML dependencies not installed: {e}",
            "hint": "Install: pip install joblib scikit-learn numpy",
        }
    except Exception as e:
        logger.error(f"Training failed: {e}", exc_info=True)
        return {"error": str(e)}
    finally:
        if conn:
            await conn.close()
