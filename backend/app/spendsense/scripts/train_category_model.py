"""
Offline trainer for category prediction model.

Trains a TF-IDF + LogisticRegression model on enriched transactions
with high confidence (>0.8) to predict categories for unknown merchants.

Usage:
    python -m app.spendsense.scripts.train_category_model
"""

import os
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

import asyncio
import logging
from decimal import Decimal

import asyncpg
import joblib
import numpy as np
from dotenv import load_dotenv
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import LabelEncoder

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

MODEL_PATH = os.getenv("CATEGORY_MODEL_PATH", "models/category_model.joblib")


async def fetch_training_data(conn: asyncpg.Connection, limit: int = 100_000):
    """
    Fetch training data from enriched transactions.

    Returns:
        (texts, amounts, labels) tuples
    """
    query = """
        SELECT 
            -- Prioritize merchant name by repeating it (same as prediction logic)
            CASE 
                WHEN f.merchant_name_norm IS NOT NULL AND f.merchant_name_norm != '' 
                THEN f.merchant_name_norm || ' ' || f.merchant_name_norm || ' ' || COALESCE(f.description, '')
                ELSE COALESCE(f.description, '')
            END AS text,
            f.amount,
            e.category_id AS category_code
        FROM spendsense.txn_fact f
        JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
        JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
        WHERE e.category_id IS NOT NULL
          AND e.confidence >= 0.8
          AND (f.description IS NOT NULL AND f.description != '' 
               OR f.merchant_name_norm IS NOT NULL AND f.merchant_name_norm != '')
        ORDER BY e.created_at DESC
        LIMIT $1
    """

    rows = await conn.fetch(query, limit)
    texts, amounts, labels = [], [], []

    for row in rows:
        text = row["text"].strip()
        if not text:
            continue

        texts.append(text)
        amounts.append(float(row["amount"]))
        labels.append(row["category_code"])

    return texts, amounts, labels


async def main():
    """Main training function."""
    load_dotenv()

    import os

    postgres_url = os.getenv("POSTGRES_URL", "")
    if not postgres_url:
        logger.error("POSTGRES_URL not found in environment")
        return

    conn = await asyncpg.connect(postgres_url)

    try:
        logger.info("Fetching training data...")
        texts, amounts, labels = await fetch_training_data(conn)

        if len(texts) < 1000:
            logger.warning(
                f"Not enough data to train model (got {len(texts)}, need at least 1000)"
            )
            return

        logger.info(f"Training on {len(texts)} transactions...")
        logger.info(f"Unique categories: {len(set(labels))}")

        # TF-IDF vectorization
        logger.info("Vectorizing text features...")
        tfidf = TfidfVectorizer(
            max_features=30000,
            ngram_range=(1, 2),  # Unigrams and bigrams
            min_df=2,  # Minimum document frequency
            stop_words="english",  # Remove common English words
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

        logger.info(f"✅ Saved model to {MODEL_PATH}")
        logger.info(f"   Categories: {len(le.classes_)}")
        logger.info(f"   Features: {X.shape[1]}")
        logger.info(f"   Training samples: {len(texts)}")

        # Print category distribution
        from collections import Counter

        cat_counts = Counter(labels)
        logger.info(f"   Top 10 categories: {dict(cat_counts.most_common(10))}")

    except Exception as e:
        logger.error(f"Training failed: {e}", exc_info=True)
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())

