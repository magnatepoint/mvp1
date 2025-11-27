"""ML model trainer for category and subcategory prediction."""

import asyncio
import json
import logging
import pickle
from pathlib import Path
from typing import Any

import asyncpg
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


class CategoryPredictor:
    """ML model for predicting transaction categories."""
    
    def __init__(self):
        self.category_model: RandomForestClassifier | None = None
        self.subcategory_model: RandomForestClassifier | None = None
        self.vectorizer: TfidfVectorizer | None = None
        self.category_encoder: LabelEncoder | None = None
        self.subcategory_encoder: LabelEncoder | None = None
        self.feature_names: list[str] = []
    
    def _extract_features(self, transactions: list[dict[str, Any]]) -> np.ndarray:
        """Extract features from transaction data."""
        features = []
        
        for txn in transactions:
            # Text features
            merchant = str(txn.get("merchant_name_norm", "")).lower()
            description = str(txn.get("description", "")).lower()
            
            # Numeric features
            amount = float(txn.get("amount", 0))
            direction = 1 if txn.get("direction") == "credit" else 0
            
            # Combine text for TF-IDF
            text = f"{merchant} {description}"
            features.append({
                "text": text,
                "amount": amount,
                "direction": direction,
            })
        
        # Vectorize text
        texts = [f["text"] for f in features]
        if self.vectorizer is None:
            self.vectorizer = TfidfVectorizer(
                max_features=500,
                ngram_range=(1, 2),
                stop_words="english",
                min_df=2,
            )
            tfidf_matrix = self.vectorizer.fit_transform(texts)
        else:
            tfidf_matrix = self.vectorizer.transform(texts)
        
        # Combine TF-IDF with numeric features
        numeric_features = np.array([
            [f["amount"], f["direction"]] for f in features
        ])
        
        # Convert sparse matrix to dense and combine
        tfidf_dense = tfidf_matrix.toarray()
        combined = np.hstack([tfidf_dense, numeric_features])
        
        return combined
    
    def train(
        self,
        transactions: list[dict[str, Any]],
        categories: list[str],
        subcategories: list[str | None],
    ) -> dict[str, Any]:
        """Train category and subcategory prediction models."""
        if len(transactions) < 10:
            logger.warning("Insufficient training data (need at least 10 samples)")
            return {"error": "Insufficient training data"}
        
        # Extract features
        X = self._extract_features(transactions)
        
        # Train category model
        self.category_encoder = LabelEncoder()
        y_category = self.category_encoder.fit_transform(categories)
        
        X_train_cat, X_test_cat, y_train_cat, y_test_cat = train_test_split(
            X, y_category, test_size=0.2, random_state=42, stratify=y_category
        )
        
        self.category_model = RandomForestClassifier(
            n_estimators=100,
            max_depth=20,
            min_samples_split=5,
            random_state=42,
            n_jobs=-1,
        )
        self.category_model.fit(X_train_cat, y_train_cat)
        cat_accuracy = self.category_model.score(X_test_cat, y_test_cat)
        
        # Train subcategory model (only for transactions with subcategories)
        subcat_data = [
            (txn, subcat) for txn, subcat in zip(transactions, subcategories) if subcat
        ]
        if len(subcat_data) >= 10:
            subcat_transactions, subcat_labels = zip(*subcat_data)
            X_subcat = self._extract_features(list(subcat_transactions))
            
            self.subcategory_encoder = LabelEncoder()
            y_subcategory = self.subcategory_encoder.fit_transform(list(subcat_labels))
            
            X_train_sub, X_test_sub, y_train_sub, y_test_sub = train_test_split(
                X_subcat, y_subcategory, test_size=0.2, random_state=42, stratify=y_subcategory
            )
            
            self.subcategory_model = RandomForestClassifier(
                n_estimators=100,
                max_depth=20,
                min_samples_split=5,
                random_state=42,
                n_jobs=-1,
            )
            self.subcategory_model.fit(X_train_sub, y_train_sub)
            subcat_accuracy = self.subcategory_model.score(X_test_sub, y_test_sub)
        else:
            self.subcategory_model = None
            subcat_accuracy = 0.0
        
        return {
            "category_accuracy": float(cat_accuracy),
            "subcategory_accuracy": float(subcat_accuracy),
            "training_samples": len(transactions),
            "category_classes": len(self.category_encoder.classes_),
            "subcategory_classes": len(self.subcategory_encoder.classes_) if self.subcategory_encoder else 0,
        }
    
    def predict(
        self,
        merchant_name: str | None,
        description: str | None,
        amount: float,
        direction: str,
    ) -> tuple[str | None, str | None, float]:
        """Predict category and subcategory for a transaction."""
        if self.category_model is None:
            return None, None, 0.0
        
        # Extract features for single transaction
        txn = {
            "merchant_name_norm": merchant_name or "",
            "description": description or "",
            "amount": amount,
            "direction": direction,
        }
        X = self._extract_features([txn])
        
        # Predict category
        cat_proba = self.category_model.predict_proba(X)[0]
        cat_idx = np.argmax(cat_proba)
        category = self.category_encoder.inverse_transform([cat_idx])[0]
        cat_confidence = float(cat_proba[cat_idx])
        
        # Predict subcategory if model exists
        subcategory = None
        subcat_confidence = 0.0
        if self.subcategory_model is not None:
            subcat_proba = self.subcategory_model.predict_proba(X)[0]
            subcat_idx = np.argmax(subcat_proba)
            subcategory = self.subcategory_encoder.inverse_transform([subcat_idx])[0]
            subcat_confidence = float(subcat_proba[subcat_idx])
        
        return category, subcategory, min(cat_confidence, subcat_confidence if subcategory else cat_confidence)
    
    def save(self, model_path: Path) -> None:
        """Save model to disk."""
        model_path.parent.mkdir(parents=True, exist_ok=True)
        with open(model_path, "wb") as f:
            pickle.dump({
                "category_model": self.category_model,
                "subcategory_model": self.subcategory_model,
                "vectorizer": self.vectorizer,
                "category_encoder": self.category_encoder,
                "subcategory_encoder": self.subcategory_encoder,
            }, f)
        logger.info(f"Model saved to {model_path}")
    
    @classmethod
    def load(cls, model_path: Path) -> "CategoryPredictor":
        """Load model from disk."""
        predictor = cls()
        with open(model_path, "rb") as f:
            data = pickle.load(f)
            predictor.category_model = data["category_model"]
            predictor.subcategory_model = data["subcategory_model"]
            predictor.vectorizer = data["vectorizer"]
            predictor.category_encoder = data["category_encoder"]
            predictor.subcategory_encoder = data["subcategory_encoder"]
        logger.info(f"Model loaded from {model_path}")
        return predictor


async def collect_training_data(conn: asyncpg.Connection, user_id: str | None = None) -> tuple[list[dict[str, Any]], list[str], list[str | None]]:
    """Collect training data from transactions and user overrides."""
    # Get transactions with their effective categories (including overrides)
    query = """
    SELECT 
        f.txn_id,
        f.merchant_name_norm,
        f.description,
        f.amount,
        f.direction,
        COALESCE(lo.category_code, e.category_code) AS category_code,
        COALESCE(lo.subcategory_code, e.subcategory_code) AS subcategory_code
    FROM spendsense.txn_fact f
    LEFT JOIN spendsense.txn_enriched e ON e.txn_id = f.txn_id
    LEFT JOIN LATERAL (
        SELECT category_code, subcategory_code
        FROM spendsense.txn_override
        WHERE txn_id = f.txn_id
        ORDER BY created_at DESC
        LIMIT 1
    ) lo ON TRUE
    WHERE COALESCE(lo.category_code, e.category_code) IS NOT NULL
    """
    
    if user_id:
        query += " AND f.user_id = $1"
        rows = await conn.fetch(query, user_id)
    else:
        rows = await conn.fetch(query)
    
    transactions = []
    categories = []
    subcategories = []
    
    for row in rows:
        transactions.append({
            "merchant_name_norm": row["merchant_name_norm"],
            "description": row["description"],
            "amount": float(row["amount"]),
            "direction": row["direction"],
        })
        categories.append(row["category_code"])
        subcategories.append(row["subcategory_code"])
    
    return transactions, categories, subcategories


async def train_ml_model(
    conn: asyncpg.Connection,
    user_id: str | None = None,
    model_type: str = "combined",
) -> dict[str, Any]:
    """Train ML model from transaction data."""
    logger.info(f"Collecting training data for user_id={user_id}, model_type={model_type}")
    
    transactions, categories, subcategories = await collect_training_data(conn, user_id)
    
    if len(transactions) < 10:
        return {
            "error": "Insufficient training data",
            "samples": len(transactions),
            "min_required": 10,
        }
    
    logger.info(f"Training on {len(transactions)} samples")
    
    # Train model
    predictor = CategoryPredictor()
    metrics = predictor.train(transactions, categories, subcategories)
    
    if "error" in metrics:
        return metrics
    
    # Save model
    model_dir = Path(settings.base_dir) / "models" / "spendsense"
    if user_id:
        model_path = model_dir / f"predictor_user_{user_id}.pkl"
    else:
        model_path = model_dir / f"predictor_global.pkl"
    
    predictor.save(model_path)
    
    # Record model version in database
    version_result = await conn.fetchrow(
        """
        SELECT COALESCE(MAX(version), 0) + 1 AS next_version
        FROM spendsense.ml_model_version
        WHERE model_type = $1 AND (user_id = $2 OR (user_id IS NULL AND $2 IS NULL))
        """,
        model_type,
        user_id,
    )
    next_version = version_result["next_version"] if version_result else 1
    
    # Deactivate old models
    await conn.execute(
        """
        UPDATE spendsense.ml_model_version
        SET is_active = FALSE
        WHERE model_type = $1 AND (user_id = $2 OR (user_id IS NULL AND $2 IS NULL))
        """,
        model_type,
        user_id,
    )
    
    # Insert new model version
    model_id = await conn.fetchval(
        """
        INSERT INTO spendsense.ml_model_version (
            model_type, version, training_samples, accuracy, model_path, is_active, metadata
        )
        VALUES ($1, $2, $3, $4, $5, TRUE, $6)
        RETURNING model_id
        """,
        model_type,
        next_version,
        len(transactions),
        metrics.get("category_accuracy", 0.0),
        str(model_path),
        json.dumps(metrics),
    )
    
    # Mark feedback as used
    await conn.execute(
        """
        UPDATE spendsense.ml_training_feedback
        SET used_in_training = TRUE, model_version = $1
        WHERE used_in_training = FALSE
        """,
        next_version,
    )
    
    return {
        "model_id": str(model_id),
        "version": next_version,
        "samples": len(transactions),
        **metrics,
    }


async def apply_merchant_feedback(conn: asyncpg.Connection) -> dict[str, Any]:
    """Persist merchant/channel edits into merchant_alias table."""
    rows = await conn.fetch(
        """
        SELECT feedback_id,
               user_id,
               original_merchant,
               corrected_merchant,
               original_channel,
               corrected_channel,
               merchant_hash
        FROM spendsense.ml_merchant_feedback
        WHERE used_in_training = FALSE
        ORDER BY feedback_at
        LIMIT 500
        """
    )
    if not rows:
        return {"processed": 0, "applied": 0}

    processed_ids: list[str] = []
    applied_count = 0

    for row in rows:
        original = _normalize_alias_text(row["original_merchant"])
        corrected = _normalize_alias_text(row["corrected_merchant"]) or original
        if not corrected:
            continue

        merchant_hash = row["merchant_hash"]
        if not merchant_hash:
            base = (original or corrected or "").lower()
            merchant_hash = hashlib.md5(base.encode("utf-8")).hexdigest()

        channel_override = row["corrected_channel"] or row["original_channel"]

        await conn.execute(
            """
            INSERT INTO spendsense.merchant_alias (
                user_id,
                merchant_hash,
                alias_pattern,
                normalized_name,
                channel_override,
                usage_count
            )
            VALUES ($1, $2, COALESCE($3, $4), $4, $5, 1)
            ON CONFLICT (user_id, merchant_hash) DO UPDATE
            SET normalized_name = COALESCE(EXCLUDED.normalized_name, spendsense.merchant_alias.normalized_name),
                channel_override = COALESCE(EXCLUDED.channel_override, spendsense.merchant_alias.channel_override),
                usage_count = spendsense.merchant_alias.usage_count + 1,
                updated_at = NOW()
            """,
            row["user_id"],
            merchant_hash,
            original,
            corrected,
            channel_override,
        )
        processed_ids.append(row["feedback_id"])
        applied_count += 1

    if processed_ids:
        await conn.execute(
            """
            UPDATE spendsense.ml_merchant_feedback
            SET used_in_training = TRUE
            WHERE feedback_id = ANY($1::uuid[])
            """,
            processed_ids,
        )

    return {"processed": len(rows), "applied": applied_count}

