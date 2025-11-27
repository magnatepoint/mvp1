-- ============================================================================
-- Parsed transaction metadata view
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

