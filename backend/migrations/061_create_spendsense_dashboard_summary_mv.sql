-- Migration: Create high-level dashboard summary materialized view
-- This view aggregates monthly income, needs, wants, and assets per user.

CREATE MATERIALIZED VIEW IF NOT EXISTS spendsense.mv_spendsense_dashboard_user_month AS
WITH enriched AS (
    SELECT
        f.user_id,
        f.txn_date,
        f.amount,
        f.direction,
        COALESCE(e.category_id, 'uncategorized') AS category_code,
        COALESCE(dc.txn_type, 'needs') AS txn_type
    FROM spendsense.txn_fact f
    LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
    LEFT JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
    LEFT JOIN spendsense.dim_category dc ON dc.category_code = e.category_id
    WHERE f.user_id IS NOT NULL
)
SELECT
    user_id,
    DATE_TRUNC('month', txn_date)::date AS month,
    COALESCE(SUM(CASE WHEN direction = 'credit' THEN amount ELSE 0 END), 0) AS income_amt,
    COALESCE(SUM(CASE WHEN txn_type = 'needs' THEN amount ELSE 0 END), 0) AS needs_amt,
    COALESCE(SUM(CASE WHEN txn_type = 'wants' THEN amount ELSE 0 END), 0) AS wants_amt,
    COALESCE(SUM(CASE WHEN txn_type = 'assets' THEN amount ELSE 0 END), 0) AS assets_amt
FROM enriched
GROUP BY user_id, DATE_TRUNC('month', txn_date)::date;

-- Create index for performance
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_spendsense_dashboard_user_month 
ON spendsense.mv_spendsense_dashboard_user_month (user_id, month);

-- Function to refresh the view (reusing the one from 060 or creating a combined one)
-- For now, we'll just have the service handle it or add it to the refresh function.
CREATE OR REPLACE FUNCTION spendsense.refresh_spendsense_dashboard_mvs()
RETURNS trigger AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY spendsense.mv_spendsense_dashboard_user_month_category;
    REFRESH MATERIALIZED VIEW CONCURRENTLY spendsense.mv_spendsense_dashboard_user_month;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
