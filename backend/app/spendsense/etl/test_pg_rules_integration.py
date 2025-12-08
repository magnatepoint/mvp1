"""
Test script for PGRulesClient integration

Run with: python -m app.spendsense.etl.test_pg_rules_integration
"""

import asyncio
import logging
from pathlib import Path

import asyncpg
from dotenv import load_dotenv

# Add parent directory to path
import sys
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent))

from app.spendsense.services.pg_rules_client import PGRulesClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def test_integration():
    """Test PGRulesClient with real database connection."""
    load_dotenv()
    
    import os
    postgres_url = os.getenv("POSTGRES_URL", "")
    if not postgres_url:
        logger.error("POSTGRES_URL not found in environment")
        return
    
    conn = await asyncpg.connect(postgres_url)
    
    try:
        logger.info("Testing PGRulesClient integration...")
        
        # Test 1: Exact match (existing merchant)
        result1 = await PGRulesClient.match_merchant(conn, "swiggy", None)
        logger.info(f"Test 1 - Exact match (swiggy): {result1}")
        assert result1 is not None
        assert result1["category_code"] == "food_dining"
        assert result1["match_kind"] == "exact"
        
        # Test 2: New merchant from migration 055
        result2 = await PGRulesClient.match_merchant(conn, "eatsure", None)
        logger.info(f"Test 2 - New merchant (eatsure): {result2}")
        assert result2 is not None
        assert result2["category_code"] == "food_dining"
        
        # Test 3: Keyword match
        result3 = await PGRulesClient.match_merchant(conn, None, "Payment to phonepe")
        logger.info(f"Test 3 - Keyword match (phonepe): {result3}")
        assert result3 is not None
        assert result3["category_code"] == "transfers_out"
        assert result3["match_kind"] == "keyword"
        
        # Test 4: Fuzzy match (typo)
        result4 = await PGRulesClient.match_merchant(conn, "swigg", None)
        logger.info(f"Test 4 - Fuzzy match (swigg typo): {result4}")
        assert result4 is not None
        assert result4["match_kind"] == "fuzzy"
        
        # Test 5: Cache test
        PGRulesClient.clear_cache()
        result5a = await PGRulesClient.match_merchant(conn, "amazon", None, use_cache=True)
        result5b = await PGRulesClient.match_merchant(conn, "amazon", None, use_cache=True)
        logger.info(f"Test 5 - Cache test: {result5a == result5b}")
        assert result5a == result5b
        
        # Test 6: No match
        result6 = await PGRulesClient.match_merchant(conn, "unknownmerchant123", None)
        logger.info(f"Test 6 - No match: {result6}")
        assert result6 is None
        
        logger.info("✅ All integration tests passed!")
        
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(test_integration())

