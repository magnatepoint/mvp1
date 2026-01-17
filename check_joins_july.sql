-- Check if July transactions are parsed and enriched
-- This will show why KPIs are zero

-- Step 1: Check parsing status
SELECT 
    COUNT(DISTINCT f.txn_id) AS total_in_fact,
    COUNT(DISTINCT tp.parsed_id) AS parsed_count,
    COUNT(DISTINCT e.parsed_id) AS enriched_count,
    COUNT(DISTINCT CASE WHEN tp.parsed_id IS NULL THEN f.txn_id END) AS not_parsed,
    COUNT(DISTINCT CASE WHEN tp.parsed_id IS NOT NULL AND e.parsed_id IS NULL THEN f.txn_id END) AS parsed_but_not_enriched
FROM spendsense.txn_fact f
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
WHERE f.user_id = '2df730e3-5329-44ff-a085-1ec75ab688b4'
  AND f.txn_date >= '2025-07-01' 
  AND f.txn_date < '2025-08-01';

-- Step 2: Check if dim_category has txn_type for the categories being used
SELECT 
    e.category_id,
    COUNT(*) AS txn_count,
    dc.txn_type,
    dc.category_name
FROM spendsense.txn_fact f
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
LEFT JOIN spendsense.dim_category dc ON dc.category_code = e.category_id
WHERE f.user_id = '2df730e3-5329-44ff-a085-1ec75ab688b4'
  AND f.txn_date >= '2025-07-01' 
  AND f.txn_date < '2025-08-01'
  AND e.category_id IS NOT NULL
GROUP BY e.category_id, dc.txn_type, dc.category_name
ORDER BY txn_count DESC
LIMIT 10;

-- Step 3: Check what txn_type values are being calculated (this is the key!)
SELECT 
    COALESCE(
        ov.txn_type,
        dc.txn_type,
        CASE 
            WHEN f.direction = 'credit' THEN 'income'
            ELSE 'needs'
        END
    ) AS calculated_txn_type,
    COUNT(*) AS transaction_count,
    SUM(f.amount) AS total_amount,
    -- Show breakdown
    COUNT(CASE WHEN ov.txn_type IS NOT NULL THEN 1 END) AS from_override,
    COUNT(CASE WHEN dc.txn_type IS NOT NULL THEN 1 END) AS from_category,
    COUNT(CASE WHEN dc.txn_type IS NULL AND ov.txn_type IS NULL THEN 1 END) AS from_fallback
FROM spendsense.txn_fact f
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
LEFT JOIN spendsense.dim_category dc ON dc.category_code = COALESCE(
    (SELECT category_code FROM spendsense.txn_override WHERE txn_id = f.txn_id ORDER BY created_at DESC LIMIT 1),
    e.category_id
)
LEFT JOIN LATERAL (
    SELECT category_code, txn_type
    FROM spendsense.txn_override
    WHERE txn_id = f.txn_id
    ORDER BY created_at DESC
    LIMIT 1
) ov ON TRUE
WHERE f.user_id = '2df730e3-5329-44ff-a085-1ec75ab688b4'
  AND f.txn_date >= '2025-07-01' 
  AND f.txn_date < '2025-08-01'
GROUP BY 
    COALESCE(
        ov.txn_type,
        dc.txn_type,
        CASE 
            WHEN f.direction = 'credit' THEN 'income'
            ELSE 'needs'
        END
    )
ORDER BY transaction_count DESC;

-- Step 4: Check if the issue is with the LEFT JOINs filtering out rows
-- This should match the 82 transactions we know exist
SELECT 
    COUNT(*) AS total_after_joins
FROM spendsense.txn_fact f
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
WHERE f.user_id = '2df730e3-5329-44ff-a085-1ec75ab688b4'
  AND f.txn_date >= '2025-07-01' 
  AND f.txn_date < '2025-08-01';

-- Step 5: Sample transactions to see what's happening
SELECT 
    f.txn_id,
    f.txn_date,
    f.amount,
    f.direction,
    tp.parsed_id IS NOT NULL AS is_parsed,
    e.parsed_id IS NOT NULL AS is_enriched,
    e.category_id AS enriched_category,
    dc.txn_type AS category_txn_type,
    COALESCE(
        ov.txn_type,
        dc.txn_type,
        CASE 
            WHEN f.direction = 'credit' THEN 'income'
            ELSE 'needs'
        END
    ) AS final_txn_type
FROM spendsense.txn_fact f
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
LEFT JOIN spendsense.dim_category dc ON dc.category_code = e.category_id
LEFT JOIN LATERAL (
    SELECT category_code, txn_type
    FROM spendsense.txn_override
    WHERE txn_id = f.txn_id
    ORDER BY created_at DESC
    LIMIT 1
) ov ON TRUE
WHERE f.user_id = '2df730e3-5329-44ff-a085-1ec75ab688b4'
  AND txn_date >= '2025-07-01' 
  AND txn_date < '2025-08-01'
ORDER BY f.txn_date DESC
LIMIT 10;
