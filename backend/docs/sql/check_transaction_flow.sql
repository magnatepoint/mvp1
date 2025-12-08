-- Check transaction flow
SELECT 
    'txn_fact' as table_name,
    COUNT(*) as count
FROM spendsense.txn_fact
UNION ALL
SELECT 
    'txn_parsed' as table_name,
    COUNT(*) as count
FROM spendsense.txn_parsed
UNION ALL
SELECT 
    'txn_enriched' as table_name,
    COUNT(*) as count
FROM spendsense.txn_enriched
UNION ALL
SELECT 
    'vw_txn_effective (with category)' as table_name,
    COUNT(*) as count
FROM spendsense.vw_txn_effective
WHERE category_code IS NOT NULL;

-- Check recent transactions
SELECT 
    f.txn_id,
    f.txn_date,
    f.description,
    tp.parsed_id IS NOT NULL as is_parsed,
    te.parsed_id IS NOT NULL as is_enriched,
    v.category_code,
    v.subcategory_code
FROM spendsense.txn_fact f
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
LEFT JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
LEFT JOIN spendsense.vw_txn_effective v ON v.txn_id = f.txn_id
ORDER BY f.txn_date DESC
LIMIT 10;
