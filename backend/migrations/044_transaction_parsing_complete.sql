-- ============================================================================
-- Transaction Parsing Complete Migration
-- Consolidates: 044, 046, 047_fix, 048_update
-- Creates txn_parsed table, view, constraints, and updates view to use table
-- ============================================================================
BEGIN;

DROP VIEW IF EXISTS spendsense.vw_txn_parsed;

CREATE VIEW spendsense.vw_txn_parsed AS
SELECT
    f.txn_id,
    f.bank_code,
    f.txn_date,
    f.amount,
    f.direction AS dr_cr,
    f.description AS raw_desc,
    /* ===== 1. txn_mode ===== */
    CASE
        WHEN f.description LIKE 'TO TRANSFER-UPI/%'
          OR f.description LIKE 'UPI-%'
          OR f.description LIKE 'UPI/CR/%'
          OR f.description LIKE 'UPI/DR/%'
          OR f.description LIKE 'UPIOUT/%'
          OR f.description LIKE 'UPI IN/%'
        THEN 'UPI'
        WHEN f.description LIKE 'BY TRANSFER-NEFT%'
          OR f.description LIKE 'NEFT-%'
        THEN 'NEFT'
        WHEN f.description LIKE 'MMT/IMPS/%'
        THEN 'IMPS'
        WHEN f.description LIKE 'BIL/%'
        THEN 'BIL'
        WHEN f.description LIKE 'IB BILLPAY DR-%'
        THEN 'CARD_BILLPAY'
        WHEN f.description LIKE 'ATM WDL-%'
        THEN 'ATM'
        WHEN f.description LIKE 'ACH D-%'
        THEN 'ACH'
        WHEN f.description LIKE 'NACH %'
        THEN 'NACH'
        ELSE 'OTHER'
    END AS txn_mode,
    /* ===== 2. derived direction ===== */
    CASE
        WHEN f.description LIKE 'BY TRANSFER-%'
          OR f.description LIKE 'UPI IN/%'
          OR f.description LIKE 'UPI/CR/%'
        THEN 'IN'
        WHEN f.description LIKE 'TO TRANSFER-%'
          OR f.description LIKE 'UPIOUT/%'
          OR f.description LIKE 'UPI/DR/%'
          OR f.description LIKE 'IB BILLPAY DR-%'
          OR f.description LIKE 'ACH D-%'
          OR f.description LIKE 'NACH %'
        THEN 'OUT'
        ELSE NULL
    END AS direction_text,
    /* ===== 3. RRN ===== */
    CASE
        WHEN f.description LIKE 'TO TRANSFER-UPI/DR/%'
        THEN split_part(f.description, '/', 3)
        WHEN f.description LIKE 'UPIOUT/%'
          OR f.description LIKE 'UPI IN/%'
        THEN split_part(f.description, '/', 2)
        WHEN f.description LIKE 'UPI/CR/%'
          OR f.description LIKE 'UPI/DR/%'
        THEN split_part(f.description, '/', 3)
        ELSE NULL
    END AS rrn,
    /* ===== 4. UTR ===== */
    CASE
        WHEN f.description ~ '^IBL[0-9a-f]+$'
        THEN f.description
        WHEN f.description LIKE 'NEFT-%'
        THEN split_part(f.description, '-', 2)
        WHEN f.description LIKE 'BY TRANSFER-NEFT%'
        THEN split_part(f.description, '*', 3)
        WHEN f.description LIKE 'UPI-%'
        THEN split_part(f.description, '-', 5)
        WHEN f.description LIKE 'REV-UPI-%'
        THEN split_part(f.description, '-', 4)
        WHEN f.description LIKE 'MMT/IMPS/%'
        THEN split_part(f.description, '/', 3)
        WHEN (f.description LIKE 'UPI/CR/%' OR f.description LIKE 'UPI/DR/%')
             AND split_part(f.description, '/', 7) = 'UPI'
        THEN split_part(f.description, '/', 8)
        ELSE NULL
    END AS utr,
    /* ===== 5. Counterparty name ===== */
    CASE
        WHEN f.description LIKE 'TO TRANSFER-UPI/DR/%'
        THEN split_part(f.description, '/', 4)
        WHEN f.description LIKE 'UPI-%'
        THEN split_part(f.description, '-', 2)
        WHEN f.description LIKE 'UPI/CR/%'
          OR f.description LIKE 'UPI/DR/%'
        THEN split_part(f.description, '/', 4)
        WHEN f.description LIKE 'MMT/IMPS/%'
        THEN split_part(f.description, '/', 4)
        WHEN f.description LIKE 'NEFT-%'
        THEN split_part(f.description, '-', 3)
        ELSE NULL
    END AS counterparty_name,
    /* ===== 6. Counterparty bank code ===== */
    CASE
        WHEN f.description LIKE 'TO TRANSFER-UPI/DR/%'
        THEN split_part(f.description, '/', 5)
        WHEN f.description LIKE 'UPI/CR/%'
          OR f.description LIKE 'UPI/DR/%'
        THEN split_part(f.description, '/', 5)
        ELSE NULL
    END AS counterparty_bank_code,
    /* ===== 7. UPI VPA ===== */
    CASE
        WHEN f.description LIKE 'TO TRANSFER-UPI/DR/%'
        THEN split_part(f.description, '/', 6)
        WHEN f.description LIKE 'UPI-%'
        THEN split_part(f.description, '-', 3)
        WHEN f.description LIKE 'REV-UPI-%'
        THEN split_part(f.description, '-', 3)
        WHEN f.description LIKE 'UPIOUT/%'
          OR f.description LIKE 'UPI IN/%'
        THEN split_part(f.description, '/', 3)
        WHEN f.description LIKE 'UPI/CR/%'
          OR f.description LIKE 'UPI/DR/%'
        THEN split_part(f.description, '/', 6)
        ELSE NULL
    END AS upi_vpa,
    CASE
        WHEN (f.description LIKE 'UPI/CR/%' OR f.description LIKE 'UPI/DR/%')
             AND split_part(f.description, '/', 6) LIKE '**%'
        THEN split_part(f.description, '/', 6)
        ELSE NULL
    END AS upi_vpa_masked,
    /* ===== 8. Platform / Gateway ===== */
    CASE
        WHEN f.description LIKE 'TO TRANSFER-UPI/DR/%'
        THEN split_part(f.description, '/', 6)
        WHEN f.description LIKE 'UPIOUT/%vyapar.%'
        THEN 'VYAPAR'
        WHEN f.description LIKE 'UPI-%BHARATPE.%'
        THEN 'BHARATPE'
        ELSE NULL
    END AS platform_or_gateway,
    /* ===== 9. IFSC ===== */
    CASE
        WHEN f.description LIKE 'UPI-%'
        THEN split_part(f.description, '-', 4)
        WHEN f.description LIKE 'MMT/IMPS/%'
        THEN split_part(f.description, '/', 5)
        WHEN f.description LIKE 'BY TRANSFER-NEFT%'
        THEN split_part(f.description, '*', 2)
        WHEN f.description LIKE 'NACH %'
        THEN split_part(f.description, ' ', 5)
        ELSE NULL
    END AS ifsc,
    /* ===== 10. Biller info ===== */
    CASE
        WHEN f.description LIKE 'BIL/%'
        THEN split_part(f.description, '/', 3)
        WHEN f.description LIKE 'IB BILLPAY DR-%'
        THEN 'HDFCCS'
        ELSE NULL
    END AS biller_name,
    CASE
        WHEN f.description LIKE 'IB BILLPAY DR-%'
        THEN split_part(f.description, '-', 2)
        ELSE NULL
    END AS biller_code,
    CASE
        WHEN f.description LIKE 'BIL/%'
        THEN split_part(f.description, '/', 4)
        WHEN f.description LIKE 'IB BILLPAY DR-%'
        THEN split_part(f.description, '-', 3)
        ELSE NULL
    END AS card_ref,
    /* ===== 11. ATM metadata ===== */
    CASE
        WHEN f.description LIKE 'ATM WDL-%'
        THEN regexp_replace(f.description, '^ATM WDL-ATM CASH ([0-9]+).*$', '\1')
        ELSE NULL
    END AS atm_txn_id,
    CASE
        WHEN f.description LIKE 'ATM WDL-%'
        THEN trim(regexp_replace(f.description, '^ATM WDL-ATM CASH [0-9]+ (.*)--$', '\1'))
        ELSE NULL
    END AS atm_location,
    /* ===== 12. Merchant category code ===== */
    CASE
        WHEN f.description LIKE 'UPIOUT/%/UPI/%'
        THEN split_part(f.description, '/', 5)
        ELSE NULL
    END AS mcc,
    /* ===== 13. ACH / NACH originators ===== */
    CASE
        WHEN f.description LIKE 'ACH D-%'
        THEN split_part(f.description, '-', 2)
        WHEN f.description LIKE 'NACH %'
        THEN split_part(f.description, ' ', 2)
        ELSE NULL
    END AS originator_name,
    CASE
        WHEN f.description LIKE 'ACH D-%'
        THEN split_part(f.description, '-', 3)
        WHEN f.description LIKE 'NACH %'
        THEN split_part(f.description, ' ', 2)
        ELSE NULL
    END AS mandate_or_run_id,
    CASE
        WHEN f.description LIKE 'NACH %'
        THEN split_part(f.description, ' ', 3)
        ELSE NULL
    END AS nach_internal_ref1,
    CASE
        WHEN f.description LIKE 'NACH %'
        THEN split_part(f.description, ' ', 4)
        ELSE NULL
    END AS nach_internal_ref2,
    /* ===== 14. Purpose / Note ===== */
    CASE
        WHEN f.description LIKE 'NEFT-%' AND f.description LIKE '%SALARY%'
        THEN 'SALARY'
        WHEN f.description LIKE 'UPI-%'
        THEN split_part(f.description, '-', 6)
        WHEN f.description LIKE 'TO TRANSFER-UPI/DR/%'
        THEN split_part(f.description, '/', 7)
        ELSE NULL
    END AS purpose,
    NULL::text AS note_text
FROM spendsense.txn_fact f;

COMMIT;

-- ============================================================================
-- Create txn_parsed table for comprehensive transaction parsing
-- ============================================================================
BEGIN;

-- Create the txn_parsed table
CREATE TABLE IF NOT EXISTS spendsense.txn_parsed (
    parsed_id           BIGSERIAL PRIMARY KEY,
    fact_txn_id         UUID         NOT NULL REFERENCES spendsense.txn_fact(txn_id) ON DELETE CASCADE,
    
    bank_code           TEXT         NOT NULL,
    txn_date            DATE         NOT NULL,
    amount              NUMERIC(18,2) NOT NULL,
    cr_dr               CHAR(1)      NOT NULL,  -- 'C' or 'D'
    
    -- Core parsing outputs
    channel_type        TEXT         NOT NULL,  -- 'UPI','IMPS','NEFT','BIL','CARD_BILLPAY','ATM','ACH','NACH','OTHER'
    direction           TEXT         NOT NULL,  -- 'IN','OUT','REV','INTERNAL'
    raw_description     TEXT         NOT NULL,
    
    -- Generic counterparty info
    counterparty_name       TEXT,
    counterparty_bank_code  TEXT,
    counterparty_vpa        TEXT,
    counterparty_account    TEXT,      -- masked or full as available
    mcc                     TEXT,      -- merchant category code where available
    
    -- Key rail-specific identifiers (only what we'll use for enrichment/dedup)
    upi_rrn             TEXT,
    imps_rrn            TEXT,
    neft_utr            TEXT,
    ach_nach_entity     TEXT,
    ach_nach_ref        TEXT,
    internal_ref        TEXT,          -- long internal IDs (IBL..., ICI..., AXI..., etc.)
    
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS ix_txn_parsed_fact_txn_id 
    ON spendsense.txn_parsed(fact_txn_id);

CREATE INDEX IF NOT EXISTS ix_txn_parsed_user_date 
    ON spendsense.txn_parsed(txn_date DESC);

CREATE INDEX IF NOT EXISTS ix_txn_parsed_channel_type 
    ON spendsense.txn_parsed(channel_type);

CREATE INDEX IF NOT EXISTS ix_txn_parsed_direction 
    ON spendsense.txn_parsed(direction);

CREATE INDEX IF NOT EXISTS ix_txn_parsed_upi_rrn 
    ON spendsense.txn_parsed(upi_rrn) 
    WHERE upi_rrn IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_txn_parsed_imps_rrn 
    ON spendsense.txn_parsed(imps_rrn) 
    WHERE imps_rrn IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_txn_parsed_neft_utr 
    ON spendsense.txn_parsed(neft_utr) 
    WHERE neft_utr IS NOT NULL;

-- Add comments
COMMENT ON TABLE spendsense.txn_parsed IS 'Parsed transaction metadata with extracted identifiers and counterparty information';
COMMENT ON COLUMN spendsense.txn_parsed.channel_type IS 'Transaction channel: UPI, IMPS, NEFT, BIL, CARD_BILLPAY, ATM, ACH, NACH, OTHER';
COMMENT ON COLUMN spendsense.txn_parsed.direction IS 'Transaction direction: IN, OUT, REV, INTERNAL';
COMMENT ON COLUMN spendsense.txn_parsed.cr_dr IS 'Credit (C) or Debit (D) indicator';
COMMENT ON COLUMN spendsense.txn_parsed.upi_rrn IS 'UPI Reference Number (RRN)';
COMMENT ON COLUMN spendsense.txn_parsed.imps_rrn IS 'IMPS Reference Number (RRN)';
COMMENT ON COLUMN spendsense.txn_parsed.neft_utr IS 'NEFT Unique Transaction Reference (UTR)';
COMMENT ON COLUMN spendsense.txn_parsed.internal_ref IS 'Internal bank reference IDs (IBL..., ICI..., AXI..., etc.)';

-- Function to populate txn_parsed from txn_fact
CREATE OR REPLACE FUNCTION spendsense.populate_txn_parsed()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO spendsense.txn_parsed (
        fact_txn_id,
        bank_code,
        txn_date,
        amount,
        cr_dr,
        channel_type,
        direction,
        raw_description,
        counterparty_name,
        counterparty_bank_code,
        counterparty_vpa,
        counterparty_account,
        mcc,
        upi_rrn,
        imps_rrn,
        neft_utr,
        ach_nach_entity,
        ach_nach_ref,
        internal_ref
    )
    SELECT
        tf.txn_id                           AS fact_txn_id,
        COALESCE(tf.bank_code, 'UNKNOWN')   AS bank_code,
        tf.txn_date,
        tf.amount,
        CASE WHEN tf.direction = 'credit' THEN 'C' ELSE 'D' END AS cr_dr,
        
        /* --------- CHANNEL DETECTION --------- */
        CASE
            -- UPI variants
            WHEN tf.description ILIKE 'UPI/%'
              OR tf.description ILIKE 'UPIOUT/%'
              OR tf.description ILIKE 'MB-IMPS-DR/%'      -- Canara MB-IMPS-DR has UPI-like ref
              OR tf.description ILIKE 'REV-UPI-%'
            THEN 'UPI'
            
            -- IMPS variants
            WHEN tf.description ILIKE 'MMT/IMPS/%'
              OR tf.description ILIKE 'BY TRANSFER-IMPS/%'
              OR tf.description ILIKE 'IMPS-%'
              OR tf.description ILIKE 'IMPS%'
              OR tf.description ILIKE 'Recd:IMPS/%'
              OR tf.description ILIKE 'INET-IMPS-%'
            THEN 'IMPS'
            
            -- NEFT
            WHEN tf.description ILIKE 'NEFT%' THEN 'NEFT'
            
            -- Bill / card-bill pay via gateways
            WHEN tf.description ILIKE 'BHDF%/BILLDK%'          -- BillDesk
              OR tf.description ILIKE '%/RAZP%'                -- Razorpay DSP Finance patterns
            THEN 'BIL'
            
            -- Card spend / POS / ATM
            WHEN tf.description ILIKE 'POS %'
              OR tf.description ILIKE 'NWD-%'
            THEN 'ATM'    -- or 'CARD_POS' if you want to split; keeping it tight → ATM/card spend
            
            -- ACH / ECS
            WHEN tf.description ILIKE 'ACH/%'
              OR tf.description ILIKE 'ACH D-%'
              OR tf.description ILIKE 'DEBIT-ACH%'
            THEN 'ACH'
            
            -- NACH
            WHEN tf.description ILIKE 'NACH-%'
              OR tf.description ILIKE 'NACH %'
            THEN 'NACH'
            
            -- Broking/CMS/interest/charges etc → OTHER
            ELSE 'OTHER'
        END AS channel_type,
        
        /* --------- DIRECTION (IN / OUT / REV / INTERNAL) --------- */
        CASE
            -- Explicit UPI direction markers for Canara / SBI etc.
            WHEN tf.description ILIKE 'UPI/CR/%' THEN 'IN'
            WHEN tf.description ILIKE 'UPI/DR/%' THEN 'OUT'
            WHEN tf.description ILIKE 'UPI/REV/%' THEN 'REV'
            
            WHEN tf.description ILIKE 'UPIOUT/%' THEN 'OUT'
            WHEN tf.description ILIKE 'Recd:IMPS/%' THEN 'IN'
            WHEN tf.description ILIKE 'INET-IMPS-CR/%' THEN 'IN'
            WHEN tf.description ILIKE 'MB-IMPS-DR/%' THEN 'OUT'
            
            WHEN tf.description ILIKE 'ACH D-%'
              OR tf.description ILIKE 'DEBIT-ACH%'
              OR tf.description ILIKE 'NACH-MUT-DR-%'
            THEN 'OUT'
            
            -- Defaults based on ledger C/D
            WHEN tf.direction = 'credit' THEN 'IN'
            WHEN tf.direction = 'debit' THEN 'OUT'
            ELSE 'OUT'
        END AS direction,
        
        tf.description AS raw_description,
        
        /* --------- COUNTERPARTY NAME (partial, bank-specific patterns) --------- */
        CASE
            -- HDFC IMPS: IMPS-<rrn>-<name>-<bank>-<acctmask>-<remark>
            WHEN COALESCE(tf.bank_code, '') ILIKE 'HDFC%'
             AND tf.description LIKE 'IMPS-%'
            THEN split_part(tf.description, '-', 3)
            
            -- ICICI IMPS MMT: MMT/IMPS/<rrn>/<name>/<ifsc>
            WHEN COALESCE(tf.bank_code, '') ILIKE 'ICICI%'
             AND tf.description LIKE 'MMT/IMPS/%'
            THEN split_part(tf.description, '/', 4)
            
            -- HDFC UPI basic: UPI-<name>-<vpa>-...
            WHEN COALESCE(tf.bank_code, '') ILIKE 'HDFC%'
             AND tf.description LIKE 'UPI-%'
            THEN split_part(tf.description, '-', 2)
            
            -- Kotak UPI: <date> UPI/<name or vpa>/<ref>/...
            WHEN COALESCE(tf.bank_code, '') ILIKE 'KOTAK%'
             AND tf.description LIKE '% UPI/%'
            THEN split_part(split_part(tf.description, ' UPI/', 2), '/', 1)
            
            -- Canara UPI: UPI/<DR|CR|REV>/<rrn>/<name>/<bank>/...
            WHEN COALESCE(tf.bank_code, '') ILIKE 'CANARA%'
             AND tf.description LIKE 'UPI/%'
            THEN split_part(tf.description, '/', 4)
            
            ELSE NULL
        END AS counterparty_name,
        
        /* --------- COUNTERPARTY BANK CODE --------- */
        CASE
            -- HDFC IMPS
            WHEN COALESCE(tf.bank_code, '') ILIKE 'HDFC%'
             AND tf.description LIKE 'IMPS-%'
            THEN split_part(tf.description, '-', 4)
            
            -- ICICI IMPS MMT (IFSC: first 4 letters)
            WHEN COALESCE(tf.bank_code, '') ILIKE 'ICICI%'
             AND tf.description LIKE 'MMT/IMPS/%'
            THEN left(split_part(tf.description, '/', 5), 4)
            
            -- Kotak IMPS Recd: Recd:IMPS/<rrn>/<status>/<bank> /<acct>/IMPST
            WHEN COALESCE(tf.bank_code, '') ILIKE 'KOTAK%'
             AND tf.description LIKE 'Recd:IMPS/%'
            THEN trim(split_part(tf.description, '/', 4))
            
            -- Canara UPI: UPI/.../<name>/<bank>/<masked_vpa>/...
            WHEN COALESCE(tf.bank_code, '') ILIKE 'CANARA%'
             AND tf.description LIKE 'UPI/%'
            THEN split_part(tf.description, '/', 5)
            
            ELSE NULL
        END AS counterparty_bank_code,
        
        /* --------- COUNTERPARTY VPA (UPI) --------- */
        CASE
            -- Canara UPI: UPI/.../<name>/<bank>/<masked_vpa>/...
            WHEN COALESCE(tf.bank_code, '') ILIKE 'CANARA%'
             AND tf.description LIKE 'UPI/%'
            THEN split_part(tf.description, '/', 6)
            
            -- HDFC UPI basic: UPI-<name>-<vpa>-...
            WHEN COALESCE(tf.bank_code, '') ILIKE 'HDFC%'
             AND tf.description LIKE 'UPI-%'
            THEN split_part(tf.description, '-', 3)
            
            -- Federal UPI OUT: UPIOUT/<ref>/<vpa>/[UPI]/<mcc>
            WHEN COALESCE(tf.bank_code, '') ILIKE 'FEDERAL%'
             AND tf.description LIKE 'UPIOUT/%'
            THEN split_part(tf.description, '/', 3)
            
            ELSE NULL
        END AS counterparty_vpa,
        
        /* --------- COUNTERPARTY ACCOUNT / CARD MASK --------- */
        CASE
            -- HDFC IMPS: ...-<acctmask>-...
            WHEN COALESCE(tf.bank_code, '') ILIKE 'HDFC%'
             AND tf.description LIKE 'IMPS-%'
            THEN split_part(tf.description, '-', 5)
            
            -- Kotak IMPS Recd: Recd:IMPS/.../<bank> /<acct>/IMPST
            WHEN COALESCE(tf.bank_code, '') ILIKE 'KOTAK%'
             AND tf.description LIKE 'Recd:IMPS/%'
            THEN split_part(tf.description, '/', 5)
            
            -- ATM / POS card mask (HDFC): POS <cardmask> ..., NWD-<cardmask>-...
            WHEN tf.description LIKE 'POS %'
            THEN split_part(tf.description, ' ', 2)
            WHEN tf.description LIKE 'NWD-%'
            THEN split_part(tf.description, '-', 2)
            
            -- Canara MB-IMPS-DR: MB-IMPS-DR/<name>/<bank>/<mask>/ ...
            WHEN COALESCE(tf.bank_code, '') ILIKE 'CANARA%'
             AND tf.description LIKE 'MB-IMPS-DR/%'
            THEN split_part(tf.description, '/', 4)
            
            ELSE NULL
        END AS counterparty_account,
        
        /* --------- MCC (where available, e.g. Federal UPI) --------- */
        CASE
            WHEN COALESCE(tf.bank_code, '') ILIKE 'FEDERAL%'
             AND tf.description LIKE 'UPIOUT/%'
            THEN split_part(tf.description, '/', array_length(string_to_array(tf.description, '/'), 1))
            ELSE NULL
        END AS mcc,
        
        /* --------- UPI_RRN --------- */
        CASE
            -- Kotak UPI: <date> UPI/<name>/<primary_ref>/UPI UPI-<rrn> ...
            WHEN COALESCE(tf.bank_code, '') ILIKE 'KOTAK%'
             AND tf.description LIKE '% UPI/%UPI UPI-%'
            THEN regexp_replace(
                     split_part(tf.description, 'UPI UPI-', 2),
                     E'[^0-9].*$',''
                 )
            
            -- SBI UPI OUT: TO TRANSFER-UPI/DR/<rrn>/...
            WHEN COALESCE(tf.bank_code, '') ILIKE 'SBI%'
             AND (tf.description LIKE 'TO TRANSFER-UPI/DR/%' OR tf.description LIKE 'BY TRANSFER-UPI/%')
            THEN split_part(tf.description, '/', 3)
            
            -- Canara UPI: UPI/<DR|CR|REV>/<rrn>/...
            WHEN COALESCE(tf.bank_code, '') ILIKE 'CANARA%'
             AND tf.description LIKE 'UPI/%'
            THEN split_part(tf.description, '/', 3)
            
            ELSE NULL
        END AS upi_rrn,
        
        /* --------- IMPS_RRN --------- */
        CASE
            -- HDFC IMPS: IMPS-<rrn>-...
            WHEN tf.description LIKE 'IMPS-%'
            THEN split_part(tf.description, '-', 2)
            
            -- ICICI IMPS MMT: MMT/IMPS/<rrn>/...
            WHEN tf.description LIKE 'MMT/IMPS/%'
            THEN split_part(tf.description, '/', 3)
            
            -- SBI BY TRANSFER-IMPS/<rrn>/...
            WHEN tf.description LIKE 'BY TRANSFER-IMPS/%'
            THEN split_part(tf.description, '/', 2)
            
            -- Kotak Recd:IMPS/<rrn>/...
            WHEN tf.description LIKE 'Recd:IMPS/%'
            THEN split_part(tf.description, '/', 2)
            
            -- Canara INET-IMPS-CR/.../<rrn> at end
            WHEN tf.description LIKE 'INET-IMPS-CR/%'
            THEN split_part(tf.description, '/', array_length(string_to_array(tf.description, '/'), 1))
            
            ELSE NULL
        END AS imps_rrn,
        
        /* --------- NEFT_UTR (placeholder) --------- */
        NULL::TEXT AS neft_utr,
        
        /* --------- ACH / NACH ENTITY & REF --------- */
        CASE
            WHEN tf.description LIKE 'ACH/%'
            THEN split_part(tf.description, '/', 2)   -- e.g. NTPC-INT-DIV..., DSPFIN...
            WHEN tf.description LIKE 'ACH D-%'
            THEN split_part(tf.description, '-', 2)   -- e.g. KISETSUSAISONFINANCE...
            WHEN tf.description LIKE 'NACH-%'
              OR tf.description LIKE 'NACH %'
            THEN split_part(tf.description, ' ', 2)   -- e.g. NSEMFS05092025CAMS...
            ELSE NULL
        END AS ach_nach_entity,
        
        CASE
            WHEN tf.description LIKE 'ACH/%'
            THEN split_part(tf.description, '/', 3)   -- trailing reference
            WHEN tf.description LIKE 'ACH D-%'
            THEN split_part(tf.description, '-', 3)   -- trailing ref/product
            WHEN tf.description LIKE 'NACH-%'
              OR tf.description LIKE 'NACH %'
            THEN split_part(tf.description, ' ', 3)   -- first numeric reference
            ELSE NULL
        END AS ach_nach_ref,
        
        /* --------- INTERNAL_REF (long IDs like ICI..., AXI..., SBI...) --------- */
        CASE
            -- Canara UPI: ...//ICI.../dd/MM/yyyy...
            WHEN COALESCE(tf.bank_code, '') ILIKE 'CANARA%'
             AND tf.description LIKE 'UPI/%//ICI%'
            THEN split_part(split_part(tf.description, '//', 2), '/', 1)
            
            -- Canara UPI via AXI / SBI rails
            WHEN COALESCE(tf.bank_code, '') ILIKE 'CANARA%'
             AND tf.description LIKE 'UPI/%//AXI%'
            THEN split_part(split_part(tf.description, '//', 2), '/', 1)
            
            WHEN COALESCE(tf.bank_code, '') ILIKE 'CANARA%'
             AND tf.description LIKE 'UPI/%//SBI%'
            THEN split_part(split_part(tf.description, '//', 2), '/', 1)
            
            ELSE NULL
        END AS internal_ref
        
    FROM spendsense.txn_fact tf
    WHERE NOT EXISTS (
        SELECT 1 FROM spendsense.txn_parsed tp 
        WHERE tp.fact_txn_id = tf.txn_id
    );
END;
$$;

COMMENT ON FUNCTION spendsense.populate_txn_parsed IS 'Populate txn_parsed table from txn_fact for transactions that have not been parsed yet';

-- Initial population (optional - can be run separately)
-- SELECT spendsense.populate_txn_parsed();

COMMIT;

-- ============================================================================
-- Fix txn_parsed table: Add unique constraint on fact_txn_id
-- ============================================================================

BEGIN;

-- Drop existing index if it exists
DROP INDEX IF EXISTS spendsense.ix_txn_parsed_fact_txn_id;

-- Add unique constraint to prevent duplicate parsing
CREATE UNIQUE INDEX IF NOT EXISTS uq_txn_parsed_fact_txn_id 
    ON spendsense.txn_parsed(fact_txn_id);

-- Add index for common queries
CREATE INDEX IF NOT EXISTS ix_txn_parsed_channel_type 
    ON spendsense.txn_parsed(channel_type);

CREATE INDEX IF NOT EXISTS ix_txn_parsed_bank_code 
    ON spendsense.txn_parsed(bank_code);

CREATE INDEX IF NOT EXISTS ix_txn_parsed_upi_rrn 
    ON spendsense.txn_parsed(upi_rrn) 
    WHERE upi_rrn IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_txn_parsed_imps_rrn 
    ON spendsense.txn_parsed(imps_rrn) 
    WHERE imps_rrn IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_txn_parsed_neft_utr 
    ON spendsense.txn_parsed(neft_utr) 
    WHERE neft_utr IS NOT NULL;

COMMIT;

-- ============================================================================
-- Update vw_txn_parsed to use the txn_parsed table instead of SQL parsing
-- ============================================================================
BEGIN;

DROP VIEW IF EXISTS spendsense.vw_txn_parsed;

CREATE VIEW spendsense.vw_txn_parsed AS
SELECT
    tp.fact_txn_id AS txn_id,
    tp.bank_code,
    tp.txn_date,
    tp.amount,
    tp.cr_dr AS dr_cr,
    tp.raw_description AS raw_desc,
    
    -- Channel type (from Python parser)
    tp.channel_type AS txn_mode,
    
    -- Direction (from Python parser)
    tp.direction AS direction_text,
    
    -- Rail-specific IDs
    tp.upi_rrn AS rrn,
    COALESCE(tp.neft_utr, tp.imps_rrn, tp.internal_ref) AS utr,
    
    -- Counterparty info
    tp.counterparty_name,
    tp.counterparty_bank_code,
    tp.counterparty_vpa AS upi_vpa,
    CASE 
        WHEN tp.counterparty_vpa LIKE '**%' THEN tp.counterparty_vpa
        ELSE NULL
    END AS upi_vpa_masked,
    
    -- Platform/Gateway (derived from VPA)
    CASE
        WHEN tp.counterparty_vpa LIKE '%vyapar%' THEN 'VYAPAR'
        WHEN tp.counterparty_vpa LIKE '%bharatpe%' THEN 'BHARATPE'
        WHEN tp.counterparty_vpa LIKE '%paytm%' THEN 'PAYTM'
        WHEN tp.counterparty_vpa LIKE '%phonepe%' THEN 'PHONEPE'
        WHEN tp.counterparty_vpa LIKE '%googlepay%' THEN 'GOOGLEPAY'
        ELSE NULL
    END AS platform_or_gateway,
    
    -- IFSC (from counterparty bank code)
    tp.counterparty_bank_code AS ifsc,
    
    -- Biller info (for ACH/NACH)
    tp.ach_nach_entity AS biller_name,
    NULL::text AS biller_code,
    tp.counterparty_account AS card_ref,
    
    -- ATM metadata (not extracted yet - can be added to Python parser)
    NULL::text AS atm_txn_id,
    NULL::text AS atm_location,
    
    -- MCC
    tp.mcc,
    
    -- ACH/NACH originators
    tp.ach_nach_entity AS originator_name,
    tp.ach_nach_ref AS mandate_or_run_id,
    NULL::text AS nach_internal_ref1,
    NULL::text AS nach_internal_ref2,
    
    -- Purpose/Note (not extracted yet - can be added to Python parser)
    NULL::text AS purpose,
    NULL::text AS note_text
    
FROM spendsense.txn_parsed tp;

COMMIT;

