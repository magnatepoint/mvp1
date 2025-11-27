-- ============================================================================
-- Fix txn_staging column name: rename "debit/credit" to "direction"
-- ============================================================================
BEGIN;

-- Rename the column from "debit/credit" to "direction" in txn_staging
-- Only rename if "debit/credit" exists and "direction" doesn't exist
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'spendsense' 
        AND table_name = 'txn_staging' 
        AND column_name = 'debit/credit'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'spendsense' 
        AND table_name = 'txn_staging' 
        AND column_name = 'direction'
    ) THEN
        ALTER TABLE spendsense.txn_staging RENAME COLUMN "debit/credit" TO direction;
    END IF;
END $$;

-- Also fix the Bank_name column (should be bank_code based on migration 036)
-- Check if Bank_name exists and rename it to bank_code if needed
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'spendsense' 
        AND table_name = 'txn_staging' 
        AND column_name = 'Bank_name'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'spendsense' 
        AND table_name = 'txn_staging' 
        AND column_name = 'bank_code'
    ) THEN
        ALTER TABLE spendsense.txn_staging RENAME COLUMN "Bank_name" TO bank_code;
    END IF;
END $$;

COMMIT;

