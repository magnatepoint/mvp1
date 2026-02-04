# Merchant Normalization and Category Matching Fixes

## Issues Identified

1. **Merchant Normalization Inconsistency**
   - `txn_fact.merchant_name_norm` was stored as Title Case (INITCAP)
   - `merchant_rules.merchant_name_norm` should be lowercase for matching
   - Matching was case-sensitive, causing rules to not match

2. **Merchant Name Cleaning**
   - Merchant names contained transaction IDs, bank codes, UPI prefixes
   - Examples: "mallashobha", "510000609-upipay", "utib0000100-602298667129-requestfromam"
   - These weren't being cleaned before normalization

3. **Category/Subcategory Matching**
   - Rules weren't matching due to normalization mismatch
   - Case-sensitive comparisons prevented matches

## Fixes Applied

### 1. Merchant Normalization (`backend/app/spendsense/etl/tasks.py`)
   - Changed `INITCAP` to `LOWER` for storing `merchant_name_norm` in `txn_fact`
   - Added aggressive merchant name cleaning to remove:
     - UPI/IMPS/NEFT/RTGS/ACH prefixes
     - Bank codes (UTIB0000100-, CNRB0006026-, etc.)
     - Transaction IDs (10+ digit numbers)
     - Common prefixes ("TO TRANSFER-", "PAYMENT FROM", etc.)
   - Normalize to lowercase for consistent matching

### 2. Merchant Matching (`backend/app/spendsense/etl/pipeline.py`)
   - Updated all `merchant_rules` joins to use `LOWER(TRIM(COALESCE(mr.merchant_name_norm, '')))`
   - Updated all `dim_merchant` joins to use `LOWER(TRIM(COALESCE(dm.normalized_name, '')))`
   - Updated similarity comparisons to use lowercase normalization
   - Ensures case-insensitive matching

### 3. Display Name (`backend/app/spendsense/service.py`)
   - API already uses `INITCAP` for display names (line 784-825)
   - `merchant_name_norm` stored as lowercase, displayed as Title Case
   - Frontend receives properly formatted display names

## Impact

- **Merchant Names**: Will be cleaned and normalized consistently
- **Category Matching**: Rules will now match correctly with case-insensitive comparison
- **Display**: Merchant names will show as Title Case in UI (e.g., "Mallashobha" instead of "mallashobha")
- **Amounts**: Already correct - no changes needed

## Next Steps

1. **Re-enrich existing transactions** to apply new normalization:
   ```bash
   python3 -m app.spendsense.scripts.re_enrich_user --user=YOUR_USER_ID
   ```

2. **Verify merchant rules** are stored as lowercase:
   ```sql
   SELECT merchant_name_norm, category_code, subcategory_code 
   FROM spendsense.merchant_rules 
   WHERE active = TRUE 
   LIMIT 10;
   ```

3. **Check if merchant_rules need normalization update**:
   ```sql
   -- Update existing rules to lowercase if needed
   UPDATE spendsense.merchant_rules
   SET merchant_name_norm = LOWER(TRIM(merchant_name_norm))
   WHERE merchant_name_norm != LOWER(TRIM(merchant_name_norm));
   ```

## Testing

After applying fixes:
1. Upload a new statement - merchant names should be cleaner
2. Check category/subcategory assignment - should match rules correctly
3. Verify amounts display correctly (should already work)
