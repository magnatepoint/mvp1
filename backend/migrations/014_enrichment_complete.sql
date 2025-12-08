-- ============================================================================
-- Migration 014: Enrichment System Complete
-- Consolidates: 049_add_enrichment_rules.sql + 050_add_txn_enriched.sql + 051_recreate_views_after_txn_enriched.sql
-- 
-- 1. Creates enrichment_rule table for pattern-based categorization
-- 2. Creates txn_enriched table (semantic layer on txn_parsed)
-- 3. Recreates views to work with txn_enriched schema
-- ============================================================================

BEGIN;

SET search_path TO spendsense, public, extensions;

-- ============================================================================
-- PART 1: Enrichment Rules Table
-- ============================================================================



-- ============================================================================
-- Create enrichment_rule table
-- ============================================================================

CREATE TABLE IF NOT EXISTS spendsense.enrichment_rule (
    rule_id         SERIAL PRIMARY KEY,
    
    -- Evaluation order: lower number = applied earlier
    priority        INT        NOT NULL,
    
    -- Optional scoping: NULL means "any"
    channel_type    TEXT,      -- 'UPI','IMPS','NEFT','ACH','NACH','ATM','BIL','OTHER', etc.
    direction       TEXT,      -- 'IN','OUT','REV','INTERNAL'
    
    -- What field we match on in txn_parsed
    match_field     TEXT NOT NULL,  
    -- e.g. 'raw_description', 'ach_nach_entity', 'ach_nach_ref', 
    --      'counterparty_name', 'mcc', 'bank_code'
    
    match_op        TEXT NOT NULL,  -- 'ILIKE', 'LIKE', 'REGEXP', 'EQUALS'
    
    -- Pattern/value for the operation (single string, you can interpret as needed)
    match_value     TEXT NOT NULL,
    
    -- Resulting categories
    cat_l1          TEXT NOT NULL,
    cat_l2          TEXT,
    cat_l3          TEXT,
    
    -- Extra semantic flags (nullable)
    transfer_type   TEXT,      -- 'SELF','P2P','BUSINESS','GOVT'
    merchant_category TEXT,    -- 'Groceries','Dining','Shopping', etc.
    is_card_payment BOOLEAN,
    is_loan_payment BOOLEAN,
    is_investment   BOOLEAN,
    
    confidence      NUMERIC(3,2) NOT NULL DEFAULT 1.0,
    rule_tag        TEXT,       -- free text identifier (e.g. 'NACH_MF_NSE_CAMS')
    
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS ix_enrichment_rule_priority 
    ON spendsense.enrichment_rule(priority) 
    WHERE active = TRUE;

CREATE INDEX IF NOT EXISTS ix_enrichment_rule_channel_direction 
    ON spendsense.enrichment_rule(channel_type, direction) 
    WHERE active = TRUE;

CREATE INDEX IF NOT EXISTS ix_enrichment_rule_match_field 
    ON spendsense.enrichment_rule(match_field) 
    WHERE active = TRUE;

CREATE INDEX IF NOT EXISTS ix_enrichment_rule_cat_l1 
    ON spendsense.enrichment_rule(cat_l1) 
    WHERE active = TRUE;

CREATE INDEX IF NOT EXISTS ix_enrichment_rule_tag 
    ON spendsense.enrichment_rule(rule_tag) 
    WHERE rule_tag IS NOT NULL;

-- Add comments
COMMENT ON TABLE spendsense.enrichment_rule IS 'Pattern-based rules for transaction enrichment and categorization';
COMMENT ON COLUMN spendsense.enrichment_rule.priority IS 'Lower number = applied earlier. Rules are evaluated in priority order.';
COMMENT ON COLUMN spendsense.enrichment_rule.match_field IS 'Field in txn_parsed to match against (e.g. raw_description, ach_nach_entity, mcc)';
COMMENT ON COLUMN spendsense.enrichment_rule.match_op IS 'Match operation: ILIKE, LIKE, REGEXP, EQUALS, IN';
COMMENT ON COLUMN spendsense.enrichment_rule.cat_l1 IS 'Level 1 category (e.g. INVESTMENT, INCOME, LOAN, EXPENSE, TRANSFER, FEE, CASH)';
COMMENT ON COLUMN spendsense.enrichment_rule.cat_l2 IS 'Level 2 category (e.g. Mutual Funds, Dividend, Loan EMI, Groceries)';
COMMENT ON COLUMN spendsense.enrichment_rule.cat_l3 IS 'Level 3 category (e.g. NSE MF / CAMS SIP, Reliance Industries, FD Premature Closure)';

-- ============================================================================
-- Investment – Mutual Funds via NACH / NSE MF / CAMS
-- ============================================================================

INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, cat_l3,
    is_investment, rule_tag
)
VALUES
(10, 'NACH', 'OUT', 'ach_nach_entity', 'ILIKE', 'NSEMFS%CAMS%',
 'INVESTMENT', 'Mutual Funds', 'NSE MF / CAMS SIP',
 TRUE, 'NACH_MF_NSE_CAMS_OUT'),

(11, 'NACH', 'OUT', 'raw_description', 'ILIKE', '%NSECLEARINGLIMITED%',
 'INVESTMENT', 'Mutual Funds', 'NSE Clearing MF',
 TRUE, 'NACH_MF_NSE_CLEARING_OUT'),

(12, 'NACH', 'OUT', 'raw_description', 'ILIKE', 'NACH-MUT-DR-%',
 'INVESTMENT', 'Mutual Funds', NULL,
 TRUE, 'NACH_MF_MUT_DR_OUT')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Income – Dividends via ACH / CMS
-- ============================================================================

-- ACH dividend credits (generic)
INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, cat_l3, is_investment, rule_tag
)
VALUES
(20, 'ACH', 'IN', 'raw_description', 'ILIKE', '%INT-DIV%',
 'INCOME', 'Dividend', NULL, TRUE, 'ACH_DIV_INT_DIV_IN'),

(21, 'ACH', 'IN', 'raw_description', 'ILIKE', '% DIV %',
 'INCOME', 'Dividend', NULL, TRUE, 'ACH_DIV_GENERIC_IN')
ON CONFLICT DO NOTHING;

-- CMS dividends (Reliance, Techno, etc.)
INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, cat_l3, is_investment, rule_tag
)
VALUES
(22, 'OTHER', 'IN', 'raw_description', 'ILIKE', 'CMS/%/RELIANCE%FINAL DIV%',
 'INCOME', 'Dividend', 'Reliance Industries', TRUE, 'CMS_DIV_RELIANCE_IN'),

(23, 'OTHER', 'IN', 'raw_description', 'ILIKE', 'CMS/%/DIV %',
 'INCOME', 'Dividend', NULL, TRUE, 'CMS_DIV_GENERIC_IN')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Income – Interest (SBINT, Int.Pd)
-- ============================================================================

INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, cat_l3, rule_tag
)
VALUES
(30, 'OTHER', 'IN', 'raw_description', 'ILIKE', '%SBINT FOR THE PERIOD%',
 'INCOME', 'Interest', 'Savings Interest', 'SBINT_SAVINGS_INT_IN'),

(31, 'OTHER', 'IN', 'raw_description', 'ILIKE', '%:Int.Pd:%',
 'INCOME', 'Interest', 'FD / RD Interest', 'INTPD_FD_RD_INT_IN')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Investments – FD Proceeds & Sweeps
-- ============================================================================

-- FD premature closure proceeds (credit)
INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, cat_l3, is_investment, rule_tag
)
VALUES
(40, 'OTHER', 'IN', 'raw_description', 'LIKE', 'FD PREMAT PROCEEDS:%',
 'INVESTMENT', 'Fixed Deposits', 'FD Premature Closure', TRUE, 'FD_PREMAT_PROCEEDS_IN')
ON CONFLICT DO NOTHING;

-- Sweep transfers into account (treated as internal/self)
INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, transfer_type, rule_tag
)
VALUES
(41, 'OTHER', 'IN', 'raw_description', 'LIKE', 'Sweep Trf From:%',
 'TRANSFER', 'Self Transfer', 'SELF', 'SWEEP_TRF_FROM_IN')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- LOAN – Loan EMIs via ACH / gateways
-- ============================================================================

-- ACH debits to loan/finance entities (NBFC, bank)
INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, is_loan_payment, is_investment, rule_tag
)
VALUES
(50, 'ACH', 'OUT', 'ach_nach_entity', 'ILIKE', '%FINANCE%',
 'LOAN', 'Loan EMI', TRUE, FALSE, 'ACH_LOAN_FINANCE_OUT'),

(51, 'ACH', 'OUT', 'raw_description', 'ILIKE', 'ACH D- NSECLEARINGLIMITED-%',
 'INVESTMENT', 'Equity & ETFs', FALSE, TRUE, 'ACH_NSE_CLEARING_EQUITY_OUT')
ON CONFLICT DO NOTHING;

-- Razorpay DSP Finance via gateway pattern
INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, is_loan_payment, rule_tag
)
VALUES
(52, 'BIL', 'OUT', 'raw_description', 'LIKE', '%/RAZPDSPFINANCEPRIVAT',
 'LOAN', 'Loan EMI', TRUE, 'BIL_DSPFIN_RAZORPAY_OUT')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- LOAN – Credit Card Payments via BillDesk / UPI
-- ============================================================================

-- BillDesk card bill payments (HDFC, Amex, ICICI)
INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, is_card_payment, rule_tag
)
VALUES
(60, 'BIL', 'OUT', 'raw_description', 'ILIKE', '%BILLDKHDFCCARD%',
 'LOAN', 'Credit Card Payment', TRUE, 'BIL_CC_HDFCCARD_OUT'),

(61, 'BIL', 'OUT', 'raw_description', 'ILIKE', '%BILLDKAMERICANEXPRES%',
 'LOAN', 'Credit Card Payment', TRUE, 'BIL_CC_AMEX_OUT'),

(62, 'BIL', 'OUT', 'raw_description', 'ILIKE', '%ICICI BANK CREDIT CA%',
 'LOAN', 'Credit Card Payment', TRUE, 'BIL_CC_ICICI_OUT')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- CASH – ATM Withdrawals
-- ============================================================================

INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, rule_tag
)
VALUES
(70, 'ATM', 'OUT', 'raw_description', 'LIKE', 'NWD-%',
 'CASH', 'ATM Withdrawal', 'ATM_NWD_OUT')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- FEE – Bank charges, DP charges, SMS, IMPS SC
-- ============================================================================

INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, rule_tag
)
VALUES
(80, NULL, 'OUT', 'raw_description', 'ILIKE', '%SMS CHARGES%',
 'FEE', 'Bank Charges', 'FEE_SMS_CHARGES_OUT'),

(81, NULL, 'OUT', 'raw_description', 'LIKE', 'DPCHG %',
 'FEE', 'DP Charges', 'FEE_DPCHG_OUT'),

(82, NULL, 'OUT', 'raw_description', 'LIKE', 'IMPS SC%',
 'FEE', 'Bank Charges', 'FEE_IMPS_SC_OUT')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- TRANSFER – P2P Friends & Family
-- ============================================================================

-- Explicit "transfer to family or friends" text
INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, transfer_type, rule_tag
)
VALUES
(90, 'IMPS', 'OUT', 'raw_description', 'ILIKE', '%TRANSFER TO FAMILY OR FRIENDS%',
 'TRANSFER', 'P2P Friends & Family', 'P2P', 'IMPS_P2P_FAMILY_OUT')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- UPI merchant categories via MCC (Federal, card rails)
-- ============================================================================

-- Groceries (MCC 5411)
INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, merchant_category, rule_tag
)
VALUES
(100, 'UPI', 'OUT', 'mcc', 'EQUALS', '5411',
 'EXPENSE', 'Groceries', 'Groceries', 'UPI_MCC_5411_GROCERY_OUT')
ON CONFLICT DO NOTHING;

-- Restaurants / Dining (MCC 5812, 5813, 5814)
INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, merchant_category, rule_tag
)
VALUES
(101, 'UPI', 'OUT', 'mcc', 'REGEXP', '^(5812|5813|5814)$',
 'EXPENSE', 'Food & Dining', 'Food & Dining', 'UPI_MCC_58XX_DINING_OUT')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Refunds / Reversals
-- ============================================================================

INSERT INTO spendsense.enrichment_rule (
    priority, channel_type, direction, match_field, match_op, match_value,
    cat_l1, cat_l2, rule_tag
)
VALUES
(110, 'UPI', 'REV', 'raw_description', 'LIKE', 'REV-UPI-%',
 'INCOME', 'Refund / Reversal', 'UPI_REV_GENERIC_IN'),

(111, 'UPI', 'IN', 'raw_description', 'ILIKE', '%reversal%',
 'INCOME', 'Refund / Reversal', 'UPI_REV_TEXT_IN')
ON CONFLICT DO NOTHING;



-- ============================================================================
-- PART 2: txn_enriched Table
-- ============================================================================



-- Ensure txn_parsed table exists (from migration 044)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'spendsense' 
        AND table_name = 'txn_parsed'
    ) THEN
        RAISE EXCEPTION 'Table spendsense.txn_parsed does not exist. Please run migration 044_transaction_parsing_complete.sql first.';
    END IF;
    
    -- Verify parsed_id column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'spendsense' 
        AND table_name = 'txn_parsed'
        AND column_name = 'parsed_id'
    ) THEN
        RAISE EXCEPTION 'Column parsed_id does not exist in spendsense.txn_parsed. Please check migration 044_transaction_parsing_complete.sql.';
    END IF;
END $$;

-- Ensure enrichment_rule table exists (from migration 049)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'spendsense' 
        AND table_name = 'enrichment_rule'
    ) THEN
        RAISE EXCEPTION 'Table spendsense.enrichment_rule does not exist. Please run migration 049_add_enrichment_rules.sql first.';
    END IF;
END $$;

-- ============================================================================
-- Create txn_enriched table
-- ============================================================================

-- Drop old txn_enriched table if it exists (different schema)
DROP TABLE IF EXISTS spendsense.txn_enriched CASCADE;

CREATE TABLE spendsense.txn_enriched (
    enriched_id       BIGSERIAL PRIMARY KEY,
    parsed_id         BIGINT       NOT NULL REFERENCES spendsense.txn_parsed(parsed_id) ON DELETE CASCADE,
    
    -- Core identity (denormalized for convenience)
    bank_code         TEXT         NOT NULL,  -- Note: using bank_code (not bank_name) to match txn_parsed
    txn_date          DATE         NOT NULL,
    amount            NUMERIC(18,2) NOT NULL,
    cr_dr             CHAR(1)      NOT NULL,  -- 'C' or 'D'
    channel_type      TEXT         NOT NULL,  -- 'UPI','IMPS','NEFT','ACH','NACH','ATM','BIL','OTHER'
    direction         TEXT         NOT NULL,  -- 'IN','OUT','REV','INTERNAL'
    
    -- Dim links (using VARCHAR codes as foreign keys)
    category_id       VARCHAR(32) REFERENCES spendsense.dim_category(category_code),
    subcategory_id    VARCHAR(48) REFERENCES spendsense.dim_subcategory(subcategory_code),
    merchant_id       UUID REFERENCES spendsense.dim_merchant(merchant_id),
    
    -- Denormalized labels (for quick reads / debugging)
    cat_l1            TEXT,        -- transaction_type from dim_category (INCOME/EXPENSE/LOAN/etc)
    cat_l2            TEXT,        -- category_name from dim_category
    cat_l3            TEXT,        -- subcategory_name from dim_subcategory
    merchant_name     TEXT,
    merchant_category TEXT,        -- high-level: Grocery / Dining / etc
    transfer_type     TEXT,        -- SELF / P2P / BUSINESS / GOVT / NULL
    is_card_payment   BOOLEAN,
    is_loan_payment   BOOLEAN,
    is_investment     BOOLEAN,
    mcc               TEXT,        -- copied from txn_parsed for convenience
    rule_id           INT REFERENCES spendsense.enrichment_rule(rule_id),
    confidence        NUMERIC(3,2) NOT NULL DEFAULT 0.0,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS ix_txn_enriched_parsed_id 
    ON spendsense.txn_enriched(parsed_id);

-- Add unique constraint on parsed_id (one-to-one relationship)
CREATE UNIQUE INDEX IF NOT EXISTS txn_enriched_parsed_id_unique 
    ON spendsense.txn_enriched(parsed_id);

CREATE INDEX IF NOT EXISTS ix_txn_enriched_category 
    ON spendsense.txn_enriched(category_id) 
    WHERE category_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_txn_enriched_subcategory 
    ON spendsense.txn_enriched(subcategory_id) 
    WHERE subcategory_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_txn_enriched_merchant 
    ON spendsense.txn_enriched(merchant_id) 
    WHERE merchant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_txn_enriched_date 
    ON spendsense.txn_enriched(txn_date DESC);

CREATE INDEX IF NOT EXISTS ix_txn_enriched_cat_l1 
    ON spendsense.txn_enriched(cat_l1) 
    WHERE cat_l1 IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_txn_enriched_rule_id 
    ON spendsense.txn_enriched(rule_id) 
    WHERE rule_id IS NOT NULL;

-- Add comments
COMMENT ON TABLE spendsense.txn_enriched IS 'Semantic layer on top of txn_parsed with enrichment rules applied and dimension mappings';
COMMENT ON COLUMN spendsense.txn_enriched.parsed_id IS 'Reference to txn_parsed.parsed_id';
COMMENT ON COLUMN spendsense.txn_enriched.cat_l1 IS 'Level 1 category (transaction type): INCOME, EXPENSE, LOAN, INVESTMENT, TRANSFER, FEE, CASH';
COMMENT ON COLUMN spendsense.txn_enriched.cat_l2 IS 'Level 2 category (category name): e.g. Mutual Funds, Dividend, Loan EMI, Groceries';
COMMENT ON COLUMN spendsense.txn_enriched.cat_l3 IS 'Level 3 category (subcategory name): e.g. NSE MF / CAMS SIP, Reliance Industries';
COMMENT ON COLUMN spendsense.txn_enriched.rule_id IS 'Reference to enrichment_rule that matched this transaction';

-- ============================================================================
-- Enrichment function: apply rules + map to dims
-- ============================================================================

CREATE OR REPLACE FUNCTION spendsense.enrich_all_transactions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = spendsense, public
AS
$$
BEGIN
    -- Insert enriched rows for any parsed transactions that are not yet enriched
    INSERT INTO spendsense.txn_enriched (
        parsed_id,
        bank_code,
        txn_date,
        amount,
        cr_dr,
        channel_type,
        direction,
        category_id,
        subcategory_id,
        merchant_id,
        cat_l1,
        cat_l2,
        cat_l3,
        merchant_name,
        merchant_category,
        transfer_type,
        is_card_payment,
        is_loan_payment,
        is_investment,
        mcc,
        rule_id,
        confidence
    )
    SELECT
        x.parsed_id,
        x.bank_code,
        x.txn_date,
        x.amount,
        x.cr_dr,
        x.channel_type,
        x.direction,
        -- category_id / subcategory_id / merchant_id will be resolved via dims below
        dc.category_code AS category_id,  -- category_code is VARCHAR primary key
        dsc.subcategory_code AS subcategory_id,  -- subcategory_code is VARCHAR primary key
        dm.merchant_id,
        -- Denormalized labels
        x.eff_cat_l1,
        x.eff_cat_l2,
        x.eff_cat_l3,
        x.eff_merchant_name,
        x.eff_merchant_category,
        x.eff_transfer_type,
        x.eff_is_card_payment,
        x.eff_is_loan_payment,
        x.eff_is_investment,
        x.mcc,
        x.eff_rule_id,
        x.eff_confidence
    FROM (
        -- 1) Base: txn_parsed that are not yet enriched
        SELECT
            p.parsed_id,
            p.bank_code,
            p.txn_date,
            p.amount,
            p.cr_dr,
            p.channel_type,
            p.direction,
            p.raw_description,
            p.counterparty_name,
            p.ach_nach_entity,
            p.ach_nach_ref,
            p.mcc,
            -- 2) Pick the best matching rule (LATERAL join)
            r.rule_id         AS eff_rule_id,
            r.cat_l1          AS rule_cat_l1,
            r.cat_l2          AS rule_cat_l2,
            r.cat_l3          AS rule_cat_l3,
            r.merchant_category AS rule_merchant_category,
            r.transfer_type   AS rule_transfer_type,
            r.is_card_payment AS rule_is_card_payment,
            r.is_loan_payment AS rule_is_loan_payment,
            r.is_investment   AS rule_is_investment,
            COALESCE(r.confidence, 1.0) AS rule_confidence,
            -- 3) Fallback categories if no rule matched
            CASE
                WHEN r.rule_id IS NOT NULL THEN r.cat_l1
                WHEN p.direction = 'OUT' AND p.channel_type = 'ATM'
                    THEN 'CASH'
                WHEN p.direction = 'OUT'
                    THEN 'EXPENSE'
                WHEN p.direction = 'IN'
                    THEN 'INCOME'
                ELSE 'UNKNOWN'
            END AS eff_cat_l1,
            CASE
                WHEN r.rule_id IS NOT NULL THEN r.cat_l2
                WHEN p.direction = 'OUT' AND p.channel_type = 'ATM'
                    THEN 'ATM Withdrawal'
                WHEN p.direction = 'OUT'
                    THEN 'Miscellaneous Expense'
                WHEN p.direction = 'IN'
                    THEN 'Other Income'
                ELSE NULL
            END AS eff_cat_l2,
            CASE
                WHEN r.rule_id IS NOT NULL THEN r.cat_l3
                ELSE NULL
            END AS eff_cat_l3,
            -- Merchant name heuristic: if we have a rule and it looks like a merchant-type
            CASE
                WHEN r.rule_id IS NOT NULL 
                     AND p.counterparty_name IS NOT NULL
                     AND p.direction = 'OUT'
                THEN p.counterparty_name
                ELSE NULL
            END AS eff_merchant_name,
            r.merchant_category AS eff_merchant_category,
            r.transfer_type     AS eff_transfer_type,
            COALESCE(r.is_card_payment, FALSE) AS eff_is_card_payment,
            COALESCE(r.is_loan_payment, FALSE) AS eff_is_loan_payment,
            COALESCE(r.is_investment,  FALSE)  AS eff_is_investment,
            COALESCE(r.confidence, 1.0)        AS eff_confidence
        FROM spendsense.txn_parsed p
        LEFT JOIN LATERAL (
            SELECT r.*
            FROM spendsense.enrichment_rule r
            WHERE
                r.active = TRUE
                -- optional channel filter
                AND (r.channel_type IS NULL OR r.channel_type = p.channel_type)
                AND (r.direction IS NULL OR r.direction = p.direction)
                AND (
                    -- match on raw_description
                    (r.match_field = 'raw_description' AND
                        CASE r.match_op
                            WHEN 'ILIKE' THEN p.raw_description ILIKE r.match_value
                            WHEN 'LIKE'  THEN p.raw_description LIKE  r.match_value
                            WHEN 'EQUALS' THEN p.raw_description =     r.match_value
                            WHEN 'REGEXP' THEN p.raw_description ~*    r.match_value
                            ELSE FALSE
                        END
                    )
                    OR
                    -- match on ach_nach_entity
                    (r.match_field = 'ach_nach_entity' AND p.ach_nach_entity IS NOT NULL AND
                        CASE r.match_op
                            WHEN 'ILIKE' THEN p.ach_nach_entity ILIKE r.match_value
                            WHEN 'LIKE'  THEN p.ach_nach_entity LIKE  r.match_value
                            WHEN 'EQUALS' THEN p.ach_nach_entity =     r.match_value
                            WHEN 'REGEXP' THEN p.ach_nach_entity ~*   r.match_value
                            ELSE FALSE
                        END
                    )
                    OR
                    -- match on ach_nach_ref
                    (r.match_field = 'ach_nach_ref' AND p.ach_nach_ref IS NOT NULL AND
                        CASE r.match_op
                            WHEN 'ILIKE' THEN p.ach_nach_ref ILIKE r.match_value
                            WHEN 'LIKE'  THEN p.ach_nach_ref LIKE  r.match_value
                            WHEN 'EQUALS' THEN p.ach_nach_ref =     r.match_value
                            WHEN 'REGEXP' THEN p.ach_nach_ref ~*    r.match_value
                            ELSE FALSE
                        END
                    )
                    OR
                    -- match on counterparty_name
                    (r.match_field = 'counterparty_name' AND p.counterparty_name IS NOT NULL AND
                        CASE r.match_op
                            WHEN 'ILIKE' THEN p.counterparty_name ILIKE r.match_value
                            WHEN 'LIKE'  THEN p.counterparty_name LIKE  r.match_value
                            WHEN 'EQUALS' THEN p.counterparty_name =     r.match_value
                            WHEN 'REGEXP' THEN p.counterparty_name ~*    r.match_value
                            ELSE FALSE
                        END
                    )
                    OR
                    -- match on MCC (supports = and REGEXP for multiple values)
                    (r.match_field = 'mcc' AND p.mcc IS NOT NULL AND
                        CASE r.match_op
                            WHEN 'EQUALS' THEN p.mcc = r.match_value
                            WHEN 'REGEXP' THEN p.mcc ~* r.match_value
                            ELSE FALSE
                        END
                    )
                )
            ORDER BY r.priority
            LIMIT 1
        ) r ON TRUE
        -- only enrich new ones (check if already enriched)
        WHERE NOT EXISTS (
            SELECT 1 FROM spendsense.txn_enriched e
            WHERE e.parsed_id = p.parsed_id
        )
    ) x
    -- Join category / subcategory / merchant dims
    LEFT JOIN spendsense.dim_category dc
           ON dc.category_name = x.eff_cat_l2
          AND dc.active = TRUE
    LEFT JOIN spendsense.dim_subcategory dsc
           ON x.eff_cat_l3 IS NOT NULL
          AND dsc.subcategory_name = x.eff_cat_l3
          AND dsc.category_code = dc.category_code
          AND dsc.active = TRUE
    LEFT JOIN spendsense.dim_merchant dm
           ON x.eff_merchant_name IS NOT NULL
          AND (
              LOWER(dm.merchant_name) = LOWER(x.eff_merchant_name)
              OR LOWER(dm.normalized_name) = LOWER(x.eff_merchant_name)
          )
          AND dm.active = TRUE;
END;
$$;

COMMENT ON FUNCTION spendsense.enrich_all_transactions IS 
'Enriches all unenriched transactions from txn_parsed by applying enrichment rules and mapping to dimension tables';



-- ============================================================================
-- PART 3: Recreate Views
-- ============================================================================



-- ============================================================================
-- Recreate mv_spendsense_dashboard_user_month
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS spendsense.mv_spendsense_dashboard_user_month CASCADE;

CREATE MATERIALIZED VIEW spendsense.mv_spendsense_dashboard_user_month AS
SELECT
    tf.user_id,
    date_trunc('month', tf.txn_date)::date AS month,
    SUM(CASE WHEN tf.direction = 'credit' THEN tf.amount ELSE 0 END) AS income_amt,
    SUM(CASE WHEN tf.direction = 'debit' 
             AND COALESCE(dc.txn_type,'wants') = 'needs' 
             AND COALESCE(te.transfer_type,'') <> 'SELF'
             THEN tf.amount ELSE 0 END) AS needs_amt,
    SUM(CASE WHEN tf.direction = 'debit' 
             AND COALESCE(dc.txn_type,'wants') = 'wants' 
             AND COALESCE(te.transfer_type,'') <> 'SELF'
             THEN tf.amount ELSE 0 END) AS wants_amt,
    SUM(CASE WHEN tf.direction = 'debit' 
             AND COALESCE(dc.txn_type,'wants') = 'assets' 
             THEN tf.amount ELSE 0 END) AS assets_amt,
    NOW() AS created_at
FROM spendsense.txn_fact tf
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
LEFT JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
LEFT JOIN spendsense.dim_category dc ON dc.category_code = te.category_id
WHERE COALESCE(te.transfer_type,'') <> 'SELF'
GROUP BY tf.user_id, date_trunc('month', tf.txn_date);

CREATE UNIQUE INDEX idx_mv_dash_user_month 
ON spendsense.mv_spendsense_dashboard_user_month(user_id, month);

COMMENT ON MATERIALIZED VIEW spendsense.mv_spendsense_dashboard_user_month IS 'Dashboard KPIs excluding self transfers';

-- ============================================================================
-- Recreate mv_spendsense_insights_user_month
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS spendsense.mv_spendsense_insights_user_month CASCADE;

CREATE MATERIALIZED VIEW spendsense.mv_spendsense_insights_user_month AS
SELECT
    tf.user_id,
    date_trunc('month', tf.txn_date)::date AS month,
    COALESCE(te.category_id, 'others') AS category_code,
    COUNT(*) AS txn_count,
    SUM(CASE WHEN tf.direction = 'debit' THEN tf.amount ELSE 0 END) AS spend_amt,
    SUM(CASE WHEN tf.direction = 'credit' THEN tf.amount ELSE 0 END) AS income_amt
FROM spendsense.txn_fact tf
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
LEFT JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
WHERE COALESCE(te.transfer_type,'') <> 'SELF'
GROUP BY tf.user_id, date_trunc('month', tf.txn_date), COALESCE(te.category_id, 'others');

CREATE UNIQUE INDEX idx_mv_insights_user_month 
ON spendsense.mv_spendsense_insights_user_month(user_id, month, category_code);

COMMENT ON MATERIALIZED VIEW spendsense.mv_spendsense_insights_user_month IS 'Insights by category excluding self transfers';

-- ============================================================================
-- Recreate vw_txn_effective
-- ============================================================================

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
  f.bank_code,
  f.channel
FROM spendsense.txn_fact f
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
LEFT JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
LEFT JOIN last_override lo ON lo.txn_id = f.txn_id;

COMMENT ON VIEW spendsense.vw_txn_effective IS 'Effective transaction view with overrides and enrichment';

-- ============================================================================
-- Recreate v_txn_for_kpi (if it exists, create a placeholder)
-- Note: This view was not found in migrations, creating a basic version
-- ============================================================================

DROP VIEW IF EXISTS spendsense.v_txn_for_kpi CASCADE;

CREATE OR REPLACE VIEW spendsense.v_txn_for_kpi AS
SELECT
  f.txn_id,
  f.user_id,
  f.txn_date,
  f.amount,
  f.direction,
  COALESCE(te.category_id, 'others') AS category_code,
  COALESCE(te.subcategory_id, NULL) AS subcategory_code,
  te.cat_l1 AS txn_type,
  te.merchant_name,
  f.bank_code,
  f.channel
FROM spendsense.txn_fact f
LEFT JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = f.txn_id
LEFT JOIN spendsense.txn_enriched te ON te.parsed_id = tp.parsed_id
WHERE COALESCE(te.transfer_type,'') <> 'SELF';

COMMENT ON VIEW spendsense.v_txn_for_kpi IS 'Transaction view for KPI calculations excluding self transfers';


COMMIT;
