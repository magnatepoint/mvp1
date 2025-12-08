-- ============================================================================
-- 046: Enrich txn_enriched metadata + expose analytics fields
-- ============================================================================

BEGIN;

SET search_path TO spendsense, public;

-- 1) Add raw_description to txn_enriched (if missing) and backfill from txn_parsed
ALTER TABLE spendsense.txn_enriched
    ADD COLUMN IF NOT EXISTS raw_description TEXT;

UPDATE spendsense.txn_enriched te
SET raw_description = tp.raw_description
FROM spendsense.txn_parsed tp
WHERE tp.parsed_id = te.parsed_id
  AND COALESCE(te.raw_description, '') = '';

-- Ensure future inserts always capture the parsed raw description
CREATE OR REPLACE FUNCTION spendsense.fn_txn_enriched_set_raw_description()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.raw_description IS NULL THEN
        SELECT raw_description
        INTO NEW.raw_description
        FROM spendsense.txn_parsed
        WHERE parsed_id = NEW.parsed_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_txn_enriched_set_raw_description
ON spendsense.txn_enriched;

CREATE TRIGGER trg_txn_enriched_set_raw_description
BEFORE INSERT OR UPDATE ON spendsense.txn_enriched
FOR EACH ROW
EXECUTE FUNCTION spendsense.fn_txn_enriched_set_raw_description();

-- 2) Recreate vw_txn_effective with merchant + channel metadata
DROP VIEW IF EXISTS spendsense.vw_txn_effective CASCADE;

CREATE OR REPLACE VIEW spendsense.vw_txn_effective AS
WITH last_override AS (
  SELECT DISTINCT ON (o.txn_id)
    o.txn_id, o.category_code, o.subcategory_code, o.txn_type, o.created_at
  FROM spendsense.txn_override o
  ORDER BY o.txn_id, o.created_at DESC
)
SELECT
  f.txn_id,
  f.user_id,
  f.txn_date,
  f.amount,
  f.direction,
  f.currency,
  f.description,
  COALESCE(lo.category_code, te.category_id) AS category_code,
  COALESCE(lo.subcategory_code, te.subcategory_id) AS subcategory_code,
  CASE
    WHEN lo.txn_type IS NOT NULL THEN lo.txn_type
    WHEN te.cat_l1 IS NOT NULL THEN 
      CASE LOWER(te.cat_l1)
        WHEN 'income' THEN 'income'
        WHEN 'expense' THEN 
          COALESCE(
            (SELECT dc.txn_type FROM spendsense.dim_category dc WHERE dc.category_code = COALESCE(lo.category_code, te.category_id)),
            'wants'
          )
        WHEN 'loan' THEN 'needs'
        WHEN 'investment' THEN 'assets'
        WHEN 'transfer' THEN 'wants'
        WHEN 'fee' THEN 'needs'
        WHEN 'cash' THEN 'wants'
        ELSE 'wants'
      END
    WHEN f.direction = 'credit' THEN 'income'
    ELSE (
      SELECT dc.txn_type
      FROM spendsense.dim_category dc
      WHERE dc.category_code = COALESCE(lo.category_code, te.category_id)
    )
  END AS txn_type,
  f.merchant_id,
  f.merchant_name_norm,
  tp.counterparty_name,
  COALESCE(te.merchant_name, tp.counterparty_name, f.merchant_name_norm) AS merchant_name,
  CASE
    WHEN COALESCE(te.transfer_type, '') IN ('P2P', 'SELF') THEN 'N'
    WHEN te.merchant_id IS NOT NULL OR te.merchant_name IS NOT NULL THEN 'Y'
    WHEN f.merchant_id IS NOT NULL THEN 'Y'
    WHEN COALESCE(TRIM(f.merchant_name_norm), '') <> '' THEN 'Y'
    ELSE 'N'
  END AS merchant_flag,
  COALESCE(tp.channel_type, te.channel_type, f.channel) AS channel_type,
  COALESCE(te.raw_description, tp.raw_description, f.description) AS raw_description,
  f.bank_code,
  f.channel,
  COALESCE(tp.created_at::time, f.created_at::time) AS txn_time
FROM spendsense.txn_fact f
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
LEFT JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
LEFT JOIN last_override lo ON lo.txn_id = f.txn_id;

COMMENT ON VIEW spendsense.vw_txn_effective IS
'Effective transaction view with overrides, enrichment metadata, merchant flag, channel, raw description and timestamps';

COMMIT;

