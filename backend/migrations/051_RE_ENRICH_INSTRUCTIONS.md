# Pan Shop Rule Migration - Re-enrichment Instructions

## Migration Status: ✅ COMPLETED

The migration `051_add_pan_shop_general_rule.sql` has been successfully applied. The following rules are now active:

1. **Merchant rule (priority 20)**: Matches "pan" in merchant names → `fd_pan_shop`
2. **Description rule (priority 20)**: Matches "pan" in descriptions → `fd_pan_shop`

## What Was Done

1. ✅ Migration executed successfully
2. ✅ Rules added to `spendsense.merchant_rules` table
3. ⏳ Re-enrichment of existing transactions (see below)

## Re-enriching Existing Transactions

The new rules will automatically apply to **future transactions**. To update **existing transactions**, you need to re-enrich them.

### Option 1: Via API Endpoint (Recommended if server is running)

If your FastAPI server is running, you can use the re-enrich endpoint:

```bash
# For a specific user (replace with your user_id and access_token)
curl -X POST "http://localhost:8000/v1/spendsense/re-enrich" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Or use the frontend UI: Navigate to SpendSense screen and click the "Re-enrich" button.

### Option 2: Via Python Script

If you have all dependencies installed:

```bash
cd backend
source venv/bin/activate  # or activate your virtual environment
pip install -r requirements.txt  # if not already installed

# Re-enrich all users
python3 app/spendsense/scripts/re_enrich_all_users_simple.py

# Or re-enrich a specific user
python3 -m app.spendsense.scripts.re_enrich_user <user_id>
```

### Option 3: Manual SQL + Re-enrich

1. Delete existing enriched records (this prepares them for re-enrichment):

```sql
-- Delete all enriched records (they will be re-created on next enrichment)
DELETE FROM spendsense.txn_enriched;
```

2. Then trigger re-enrichment via API or Python script (see options above).

## Verification

To verify the rules are working, check transactions with "pan" in merchant or description:

```sql
-- Check if pan shop transactions are being categorized correctly
SELECT 
    v.txn_date,
    v.merchant_name_norm,
    v.description,
    v.category_code,
    v.subcategory_code,
    v.amount
FROM spendsense.vw_txn_effective v
WHERE LOWER(v.merchant_name_norm) LIKE '%pan%'
   OR LOWER(v.description) LIKE '%pan%'
ORDER BY v.txn_date DESC
LIMIT 20;
```

They should all have:
- `category_code = 'food_dining'`
- `subcategory_code = 'fd_pan_shop'`

## Future Transactions

All **new transactions** uploaded after the migration will automatically use the new pan shop rules. No action needed for future transactions.

