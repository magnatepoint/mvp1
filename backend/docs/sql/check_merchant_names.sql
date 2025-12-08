-- Check current state of merchant names
SELECT 
    merchant_name_norm,
    COUNT(*) as count,
    CASE 
        WHEN merchant_name_norm IS NULL THEN 'NULL'
        WHEN LOWER(SUBSTRING(merchant_name_norm FROM 1 FOR 1)) = SUBSTRING(merchant_name_norm FROM 1 FOR 1) 
            AND LENGTH(merchant_name_norm) > 1 
            AND UPPER(SUBSTRING(merchant_name_norm FROM 2 FOR 1)) != SUBSTRING(merchant_name_norm FROM 2 FOR 1)
        THEN 'Lowercase (needs fixing)'
        WHEN LOWER(TRIM(merchant_name_norm)) IN ('to', 'from', 'to transfer', 'from transfer', 'transfer', 'payment', 'debit', 'credit', 'unknown')
        THEN 'Generic term (should be NULL)'
        ELSE 'Properly formatted'
    END as status
FROM spendsense.txn_fact
WHERE merchant_name_norm IS NOT NULL
GROUP BY merchant_name_norm, status
ORDER BY count DESC
LIMIT 20;

-- Show some sample transactions
SELECT 
    txn_date,
    merchant_name_norm,
    description,
    amount,
    direction
FROM spendsense.txn_fact
WHERE merchant_name_norm IS NOT NULL
ORDER BY txn_date DESC
LIMIT 10;

