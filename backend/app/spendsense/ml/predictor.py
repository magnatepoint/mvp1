"""ML prediction service for category/subcategory prediction."""

import logging
from pathlib import Path
from typing import Any

import asyncpg

from app.core.config import get_settings
from .trainer import CategoryPredictor

logger = logging.getLogger(__name__)
settings = get_settings()


class MLPredictorService:
    """Service for ML-based category/subcategory prediction."""
    
    def __init__(self):
        self._global_model: CategoryPredictor | None = None
        self._user_models: dict[str, CategoryPredictor] = {}
        self._model_dir = Path(settings.base_dir) / "models" / "spendsense"
        self._model_dir.mkdir(parents=True, exist_ok=True)
    
    def _load_model(self, user_id: str | None = None) -> CategoryPredictor | None:
        """Load model for user (or global if None)."""
        if user_id:
            if user_id in self._user_models:
                return self._user_models[user_id]
            model_path = self._model_dir / f"predictor_user_{user_id}.pkl"
        else:
            if self._global_model:
                return self._global_model
            model_path = self._model_dir / f"predictor_global.pkl"
        
        if not model_path.exists():
            return None
        
        try:
            predictor = CategoryPredictor.load(model_path)
            if user_id:
                self._user_models[user_id] = predictor
            else:
                self._global_model = predictor
            return predictor
        except Exception as e:
            logger.error(f"Failed to load model from {model_path}: {e}")
            return None
    
    async def predict(
        self,
        conn: asyncpg.Connection,
        merchant_name: str | None,
        description: str | None,
        amount: float,
        direction: str,
        user_id: str | None = None,
    ) -> tuple[str | None, str | None, float]:
        """Predict category and subcategory using ML model.
        
        Returns:
            (category_code, subcategory_code, confidence)
        """
        # Try user-specific model first, then global
        predictor = self._load_model(user_id)
        if predictor is None:
            predictor = self._load_model(None)  # Try global model
        
        if predictor is None:
            return None, None, 0.0
        
        try:
            category, subcategory, confidence = predictor.predict(
                merchant_name, description, amount, direction
            )
            return category, subcategory, confidence
        except Exception as e:
            logger.error(f"Prediction failed: {e}")
            return None, None, 0.0
    
    async def record_feedback(
        self,
        conn: asyncpg.Connection,
        txn_id: str,
        user_id: str,
        original_category: str | None,
        original_subcategory: str | None,
        corrected_category: str,
        corrected_subcategory: str | None,
        merchant_name: str | None,
        description: str | None,
        amount: float,
        direction: str,
    ) -> None:
        """Record user correction for ML training."""
        await conn.execute(
            """
            INSERT INTO spendsense.ml_training_feedback (
                txn_id, user_id, original_category_code, original_subcategory_code,
                corrected_category_code, corrected_subcategory_code,
                merchant_name_norm, description, amount, direction
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            """,
            txn_id,
            user_id,
            original_category,
            original_subcategory,
            corrected_category,
            corrected_subcategory,
            merchant_name,
            description,
            amount,
            direction,
        )
        logger.info(f"Recorded feedback for txn_id={txn_id}, user_id={user_id}")


# Global singleton instance
_predictor_service: MLPredictorService | None = None


def get_predictor_service() -> MLPredictorService:
    """Get global ML predictor service instance."""
    global _predictor_service
    if _predictor_service is None:
        _predictor_service = MLPredictorService()
    return _predictor_service

