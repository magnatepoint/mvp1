-- Migration: Create materialized view for SpendSense dashboard optimization
-- This view aggregates transaction counts and amounts by user, month, and category.

CREATE MATERIALIZED VIEW IF NOT EXISTS spendsense.mv_spendsense_dashboard_user_month_category AS
SELECT 
    f.user_id,
    DATE_TRUNC('month', f.txn_date)::date AS month,
    COALESCE(e.category_id, 'uncategorized') AS category_code,
    COUNT(*) AS txn_count,
    SUM(CASE WHEN f.direction = 'debit' THEN f.amount ELSE 0 END) AS spend_amount,
    SUM(CASE WHEN f.direction = 'credit' THEN f.amount ELSE 0 END) AS income_amount
FROM spendsense.txn_fact f
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
WHERE f.user_id IS NOT NULL
GROUP BY f.user_id, DATE_TRUNC('month', f.txn_date)::date, e.category_id;

-- Create indexes for performance
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_spendsense_dashboard_user_month_cat 
ON spendsense.mv_spendsense_dashboard_user_month_category (user_id, month, category_code);

CREATE INDEX IF NOT EXISTS idx_mv_spendsense_month 
ON spendsense.mv_spendsense_dashboard_user_month_category (month);

-- Function to refresh the view
CREATE OR REPLACE FUNCTION spendsense.refresh_spendsense_dashboard_mv()
RETURNS trigger AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY spendsense.mv_spendsense_dashboard_user_month_category;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Since this is an analytics dashboard, we might want to refresh it on demand or periodically.
-- For now, the existing service.py fallback handles cases where it might be slightly stale.
