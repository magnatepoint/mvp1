-- Test enrichment query
-- Check if there are parsed transactions without enrichment
SELECT 
    COUNT(*) as unenriched_count,
    COUNT(DISTINCT tp.parsed_id) as unique_parsed_ids,
    COUNT(DISTINCT f.user_id) as unique_users
FROM spendsense.txn_parsed tp
JOIN spendsense.txn_fact f ON tp.fact_txn_id = f.txn_id
WHERE NOT EXISTS (
    SELECT 1 FROM spendsense.txn_enriched te
    WHERE te.parsed_id = tp.parsed_id
);

-- Check if fn_match_merchant exists
SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'spendsense'
    AND p.proname = 'fn_match_merchant'
) as fn_exists;

-- Sample a few parsed transactions
SELECT 
    tp.parsed_id,
    f.user_id,
    f.merchant_name_norm,
    f.description,
    tp.channel_type,
    tp.direction
FROM spendsense.txn_parsed tp
JOIN spendsense.txn_fact f ON tp.fact_txn_id = f.txn_id
WHERE NOT EXISTS (
    SELECT 1 FROM spendsense.txn_enriched te
    WHERE te.parsed_id = tp.parsed_id
)
LIMIT 5;
