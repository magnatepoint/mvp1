"""
PostgreSQL Rules Client

Thin client wrapper around Postgres rule functions, specifically:
- spendsense.fn_match_merchant(merchant_name, description)

Provides caching and Python-friendly interface for merchant matching.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Dict, Optional, Tuple

import asyncpg

logger = logging.getLogger(__name__)


class PGRulesClient:
    """
    Thin client around Postgres rule functions.
    
    Currently only uses spendsense.fn_match_merchant(merchant, description).
    Provides in-memory caching for performance.
    """

    # Simple in-memory cache: key -> result dict|None
    _merchant_cache: Dict[Tuple[str, str], Optional[Dict[str, Any]]] = {}

    @classmethod
    def clear_cache(cls) -> None:
        """Clear the in-memory merchant matching cache."""
        cls._merchant_cache.clear()
        logger.debug("Cleared merchant matching cache")

    @classmethod
    async def match_merchant(
        cls,
        conn: asyncpg.Connection,
        merchant_name: Optional[str],
        description: Optional[str] = None,
        user_id: Optional[str] = None,  # kept for future per-user rules
        use_cache: bool = True,
    ) -> Optional[Dict[str, Any]]:
        """
        Call spendsense.fn_match_merchant and return a Python dict.
        
        Args:
            conn: Database connection (asyncpg)
            merchant_name: Raw merchant name from transaction
            description: Optional transaction description
            user_id: User ID (for future per-user rules)
            use_cache: Whether to use in-memory cache
            
        Returns:
            Dict with keys:
                - rule_id: UUID of matched rule
                - merchant_name_norm: Normalized merchant name
                - category_code: Category code (e.g., 'food_dining')
                - subcategory_code: Subcategory code (e.g., 'fd_online')
                - confidence: Confidence score (0.70-1.0)
                - match_kind: 'exact' | 'fuzzy' | 'keyword'
            Returns None if no rule matched.
        """
        m = (merchant_name or "").strip()
        d = (description or "").strip()

        cache_key = (m.lower(), d.lower())

        if use_cache and cache_key in cls._merchant_cache:
            return cls._merchant_cache[cache_key]

        if not m and not d:
            return None

        try:
            result = await conn.fetchval(
                "SELECT spendsense.fn_match_merchant($1, $2)",
                m or None,
                d or None,
            )

            if result is None:
                match = None
            elif isinstance(result, dict):
                match = result
            elif isinstance(result, str):
                # JSON string case
                try:
                    match = json.loads(result)
                except Exception:
                    match = None
            else:
                # Row-like object -> convert using _mapping if present
                try:
                    match = dict(result._mapping)  # type: ignore[attr-defined]
                except Exception:
                    match = None

            if use_cache:
                cls._merchant_cache[cache_key] = match

            return match
        except Exception as exc:
            logger.error(f"Error calling fn_match_merchant: {exc}", exc_info=True)
            return None

    @classmethod
    def match_merchant_sync(
        cls,
        merchant_name: Optional[str],
        description: Optional[str] = None,
        user_id: Optional[str] = None,
        use_cache: bool = True,
    ) -> Optional[Dict[str, Any]]:
        """
        Synchronous version using SQLAlchemy (for non-async contexts).
        
        Note: This requires SQLAlchemy session. For async contexts, use match_merchant().
        
        Args:
            merchant_name: Raw merchant name from transaction
            description: Optional transaction description
            user_id: User ID (for future per-user rules)
            use_cache: Whether to use in-memory cache
            
        Returns:
            Dict with rule details or None if no match
        """
        from sqlalchemy import text
        from sqlalchemy.orm import Session

        # Try to get session from context or create new one
        # This is a fallback for sync contexts
        try:
            from app.database.postgresql import SessionLocal
            session: Session = SessionLocal()
        except ImportError:
            logger.warning("SQLAlchemy SessionLocal not available, cannot use sync version")
            return None

        m = (merchant_name or "").strip()
        d = (description or "").strip()

        cache_key = (m.lower(), d.lower())

        if use_cache and cache_key in cls._merchant_cache:
            session.close()
            return cls._merchant_cache[cache_key]

        if not m and not d:
            session.close()
            return None

        try:
            result = session.execute(
                text("SELECT spendsense.fn_match_merchant(:m, :d)"),
                {"m": m or None, "d": d or None},
            ).scalar()

            if result is None:
                match = None
            elif isinstance(result, dict):
                match = result
            elif isinstance(result, str):
                try:
                    match = json.loads(result)
                except Exception:
                    match = None
            else:
                try:
                    match = dict(result._mapping)  # type: ignore[attr-defined]
                except Exception:
                    match = None

            if use_cache:
                cls._merchant_cache[cache_key] = match

            return match
        except Exception as exc:
            logger.error(f"Error calling fn_match_merchant (sync): {exc}", exc_info=True)
            return None
        finally:
            session.close()

