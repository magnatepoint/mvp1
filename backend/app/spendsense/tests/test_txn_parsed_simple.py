"""
Simple tests for txn_parsed table - database only, no parser imports
"""
import asyncio
import asyncpg
import sys
from pathlib import Path

# Add backend to path
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))

from app.core.config import get_settings


async def run_tests():
    """Run all tests"""
    settings = get_settings()
    conn = await asyncpg.connect(str(settings.postgres_dsn), statement_cache_size=0)
    
    passed = 0
    failed = 0
    
    try:
        print("="*80)
        print("TXN_PARSED DATABASE TESTS")
        print("="*80)
        
        # Test 1: Table exists
        print("\n✓ Test 1: txn_parsed table exists")
        exists = await conn.fetchval("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'spendsense' AND table_name = 'txn_parsed'
            )
        """)
        if exists:
            print("  ✅ PASS")
            passed += 1
        else:
            print("  ❌ FAIL")
            failed += 1
        
        # Test 2: View exists
        print("\n✓ Test 2: vw_txn_parsed view exists")
        exists = await conn.fetchval("""
            SELECT EXISTS (
                SELECT FROM information_schema.views 
                WHERE table_schema = 'spendsense' AND table_name = 'vw_txn_parsed'
            )
        """)
        if exists:
            print("  ✅ PASS")
            passed += 1
        else:
            print("  ❌ FAIL")
            failed += 1
        
        # Test 3: Table has data
        print("\n✓ Test 3: txn_parsed table has data")
        count = await conn.fetchval("SELECT COUNT(*) FROM spendsense.txn_parsed")
        print(f"  Found {count} records")
        if count > 0:
            print("  ✅ PASS")
            passed += 1
        else:
            print("  ❌ FAIL")
            failed += 1
        
        # Test 4: View has data
        print("\n✓ Test 4: vw_txn_parsed view has data")
        count = await conn.fetchval("SELECT COUNT(*) FROM spendsense.vw_txn_parsed")
        print(f"  Found {count} records")
        if count > 0:
            print("  ✅ PASS")
            passed += 1
        else:
            print("  ❌ FAIL")
            failed += 1
        
        # Test 5: Table and view match
        print("\n✓ Test 5: Table and view have same count")
        table_count = await conn.fetchval("SELECT COUNT(*) FROM spendsense.txn_parsed")
        view_count = await conn.fetchval("SELECT COUNT(*) FROM spendsense.vw_txn_parsed")
        if table_count == view_count:
            print(f"  Both have {table_count} records")
            print("  ✅ PASS")
            passed += 1
        else:
            print(f"  Table: {table_count}, View: {view_count}")
            print("  ❌ FAIL")
            failed += 1
        
        # Test 6: UPI transactions have rich data
        print("\n✓ Test 6: UPI transactions have rich data")
        upi_count = await conn.fetchval("""
            SELECT COUNT(*) FROM spendsense.txn_parsed 
            WHERE channel_type = 'UPI' AND counterparty_name IS NOT NULL
        """)
        print(f"  Found {upi_count} UPI transactions with counterparty")
        if upi_count > 0:
            print("  ✅ PASS")
            passed += 1
        else:
            print("  ❌ FAIL")
            failed += 1
        
        # Test 7: UPI RRN extraction
        print("\n✓ Test 7: UPI RRN extraction works")
        rrn_count = await conn.fetchval("""
            SELECT COUNT(*) FROM spendsense.txn_parsed 
            WHERE upi_rrn IS NOT NULL
        """)
        print(f"  Found {rrn_count} transactions with UPI RRN")
        if rrn_count > 0:
            print("  ✅ PASS")
            passed += 1
        else:
            print("  ❌ FAIL")
            failed += 1
        
        # Test 8: Rich data coverage
        print("\n✓ Test 8: Good coverage of rich data")
        total = await conn.fetchval("SELECT COUNT(*) FROM spendsense.txn_parsed")
        with_data = await conn.fetchval("""
            SELECT COUNT(*) FROM spendsense.txn_parsed 
            WHERE counterparty_name IS NOT NULL OR upi_rrn IS NOT NULL OR imps_rrn IS NOT NULL
        """)
        percentage = (with_data / total * 100) if total > 0 else 0
        print(f"  {with_data}/{total} records have rich data ({percentage:.1f}%)")
        if percentage >= 50:
            print("  ✅ PASS")
            passed += 1
        else:
            print("  ❌ FAIL")
            failed += 1
        
    finally:
        await conn.close()
    
    # Summary
    print("\n" + "="*80)
    print("TEST SUMMARY")
    print("="*80)
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {failed}")
    print(f"Total: {passed + failed}")
    
    if failed == 0:
        print("\n🎉 ALL TESTS PASSED!")
    else:
        print(f"\n⚠️  {failed} test(s) failed")
    
    print("="*80)
    
    return failed == 0


if __name__ == "__main__":
    success = asyncio.run(run_tests())
    sys.exit(0 if success else 1)

