"""
ML Category Prediction Service

Thin wrapper around a scikit-learn model for predicting transaction categories
when rule-based matching fails.
"""

from __future__ import annotations

import logging
import os
from decimal import Decimal
from functools import lru_cache
from typing import Optional

import numpy as np

logger = logging.getLogger(__name__)

# Try to import ML dependencies (optional)
try:
    import joblib
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.preprocessing import LabelEncoder

    ML_AVAILABLE = True
except ImportError:
    ML_AVAILABLE = False
    logger.warning(
        "ML dependencies (joblib, scikit-learn) not available. ML fallback will be disabled."
    )

MODEL_PATH = os.getenv("CATEGORY_MODEL_PATH", "models/category_model.joblib")


class CategoryModelNotAvailable(Exception):
    """Raised when ML model is not available."""

    pass


@lru_cache(maxsize=1)
def _load_model():
    """Load the ML model bundle from disk."""
    if not ML_AVAILABLE:
        raise CategoryModelNotAvailable("ML dependencies not installed")

    if not os.path.exists(MODEL_PATH):
        raise CategoryModelNotAvailable(f"Model file not found at {MODEL_PATH}")

    try:
        bundle = joblib.load(MODEL_PATH)
        # bundle: {"vectorizer": tfidf, "model": clf, "label_encoder": le}
        if not all(k in bundle for k in ["vectorizer", "model", "label_encoder"]):
            raise CategoryModelNotAvailable("Invalid model bundle format")
        return bundle
    except Exception as e:
        logger.error(f"Error loading ML model: {e}")
        raise CategoryModelNotAvailable(f"Failed to load model: {e}")


def ml_predict_category(
    description: str,
    merchant: Optional[str],
    amount: float | Decimal,
) -> Optional[dict]:
    """
    Predict transaction category using ML model.

    Args:
        description: Transaction description
        merchant: Merchant name (optional)
        amount: Transaction amount

    Returns:
        {
            "category_code": str,
            "confidence": float
        } or None if model not available.
    """
    try:
        bundle = _load_model()
    except CategoryModelNotAvailable:
        return None

    # Combine merchant and description for text features
    # Prioritize merchant name by repeating it (gives it more weight in TF-IDF)
    # Format: "MERCHANT MERCHANT description" to emphasize merchant name
    merchant_part = (merchant or "").strip()
    desc_part = (description or "").strip()
    
    if merchant_part:
        # Repeat merchant name to give it more weight in TF-IDF
        text = f"{merchant_part} {merchant_part} {desc_part}".strip()
    else:
        # If no merchant, just use description
        text = desc_part
    
    if not text:
        return None

    try:
        # Transform text using TF-IDF
        vec = bundle["vectorizer"].transform([text])

        # Include amount as a feature
        amt = float(amount) if amount is not None else 0.0
        amt_arr = np.array([[amt]])

        # Combine text features with amount
        X = np.hstack([vec.toarray(), amt_arr])

        # Predict probabilities
        probs = bundle["model"].predict_proba(X)[0]
        idx = int(probs.argmax())
        cat_code = bundle["label_encoder"].inverse_transform([idx])[0]
        prob = float(probs[idx])

        return {"category_code": cat_code, "confidence": prob}
    except Exception as e:
        logger.error(f"Error during ML prediction: {e}")
        return None


def is_ml_available() -> bool:
    """Check if ML model is available."""
    try:
        _load_model()
        return True
    except CategoryModelNotAvailable:
        return False

