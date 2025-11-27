-- ============================================================================
-- Migration 042: Add Merchant Rules from Coverage Audit
-- Based on audit showing 463/675 transactions (69%) without rule matches
-- ============================================================================
BEGIN;

-- ============================================================================
-- 1. PAN Shop / Cigarette Rules (Personal UPI transfers)
-- Map to: food_dining / fd_pan_shop
-- ============================================================================

-- Rule for UPI patterns with personal names (PAN shop transactions)
INSERT INTO spendsense.merchant_rules (
    priority, applies_to, pattern_regex, category_code, subcategory_code, active, pattern_hash, source, tenant_id
)
VALUES (
    50, 'description', 
    'UPI-(?:KIRANKUMAR|MOHAMMED SAMEER|SHAIK SAMEER|ARIFA BEGUM|MAREPALLY|SYED MOHAMMED|GANGADARA|MARKAPUDI|MUJEEB|VASANTHAKUMARI)\s+[A-Z\s]+',
    'food_dining', 'fd_pan_shop', TRUE,
    MD5('UPI-PAN-PERSONAL-NAMES'), 'ops', NULL
)
ON CONFLICT DO NOTHING;

-- Individual merchant name rules for PAN shop UPI transfers
INSERT INTO spendsense.merchant_rules (
    priority, applies_to, pattern_regex, category_code, subcategory_code, active, pattern_hash, source, tenant_id
)
VALUES
    (60, 'merchant', 'kirankumar\s+k\s+v\s+k\s+n', 'food_dining', 'fd_pan_shop', TRUE, MD5('merchant-kirankumar-k-v-k-n'), 'ops', NULL),
    (60, 'merchant', 'mohammed\s+sameer', 'food_dining', 'fd_pan_shop', TRUE, MD5('merchant-mohammed-sameer'), 'ops', NULL),
    (60, 'merchant', 'shaik\s+sameer\s+ahmed', 'food_dining', 'fd_pan_shop', TRUE, MD5('merchant-shaik-sameer-ahmed'), 'ops', NULL),
    (60, 'merchant', 'arifa\s+begum', 'food_dining', 'fd_pan_shop', TRUE, MD5('merchant-arifa-begum'), 'ops', NULL),
    (60, 'merchant', 'marepally\s+devendar', 'food_dining', 'fd_pan_shop', TRUE, MD5('merchant-marepally-devendar'), 'ops', NULL),
    (60, 'merchant', 'syed\s+mohammed\s+ali', 'food_dining', 'fd_pan_shop', TRUE, MD5('merchant-syed-mohammed-ali'), 'ops', NULL),
    (60, 'merchant', 'gangadara\s+nagalaxmi', 'food_dining', 'fd_pan_shop', TRUE, MD5('merchant-gangadara-nagalaxmi'), 'ops', NULL),
    (60, 'merchant', 'markapudi\s+prasanna', 'food_dining', 'fd_pan_shop', TRUE, MD5('merchant-markapudi-prasanna'), 'ops', NULL)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 2. Credit Card Payment Rules
-- Map to: loans_payments / loan_cc_bill
-- ============================================================================

-- CRED Club credit card payment
INSERT INTO spendsense.merchant_rules (
    priority, applies_to, pattern_regex, category_code, subcategory_code, active, pattern_hash, source, tenant_id
)
VALUES (
    40, 'merchant', 'cred\s+club', 'loans_payments', 'loan_cc_bill', TRUE,
    MD5('merchant-cred-club'), 'ops', NULL
)
ON CONFLICT DO NOTHING;

-- HDFC BillPay (4Wheeler/Card Services)
INSERT INTO spendsense.merchant_rules (
    priority, applies_to, pattern_regex, category_code, subcategory_code, active, pattern_hash, source, tenant_id
)
VALUES
    (40, 'description', 'IB\s+BILLPAY\s+DR-HDFC4W-', 'loans_payments', 'loan_cc_bill', TRUE, MD5('desc-ib-billpay-hdfc4w'), 'ops', NULL),
    (40, 'description', 'IB\s+BILLPAY\s+DR-HDFCCS-', 'loans_payments', 'loan_cc_bill', TRUE, MD5('desc-ib-billpay-hdfccs'), 'ops', NULL)
ON CONFLICT DO NOTHING;

-- American Express credit card payment
INSERT INTO spendsense.merchant_rules (
    priority, applies_to, pattern_regex, category_code, subcategory_code, active, pattern_hash, source, tenant_id
)
VALUES (
    40, 'merchant', 'american\s+express', 'loans_payments', 'loan_cc_bill', TRUE,
    MD5('merchant-american-express'), 'ops', NULL
)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 3. Personal Loan EMI Rules
-- Map to: loans_payments / loan_personal
-- ============================================================================

-- Razorpay Software Private (Personal Loan EMI)
INSERT INTO spendsense.merchant_rules (
    priority, applies_to, pattern_regex, category_code, subcategory_code, active, pattern_hash, source, tenant_id
)
VALUES (
    40, 'merchant', 'razorpaysoftwarepriv', 'loans_payments', 'loan_personal', TRUE,
    MD5('merchant-razorpaysoftwarepriv'), 'ops', NULL
)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 4. Mutual Fund / Investment Rules
-- Map to: investments_commitments / inv_sip
-- ============================================================================

-- NSE Clearing Limited (Mutual Fund transactions)
INSERT INTO spendsense.merchant_rules (
    priority, applies_to, pattern_regex, category_code, subcategory_code, active, pattern_hash, source, tenant_id
)
VALUES (
    30, 'merchant', 'nseclearinglimited', 'investments_commitments', 'inv_sip', TRUE,
    MD5('merchant-nseclearinglimited'), 'ops', NULL
)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 5. Income / Salary Rules
-- Map to: income / inc_salary
-- ============================================================================

-- NEFT Credit from employer (MAGNATEPOINT TECHNOLOGIES)
INSERT INTO spendsense.merchant_rules (
    priority, applies_to, pattern_regex, category_code, subcategory_code, active, pattern_hash, source, tenant_id
)
VALUES (
    20, 'description', 'NEFT\s+CR-IDFB0010204-MAGNATEPOINT\s+TECHNOLOGIES', 'income', 'inc_salary', TRUE,
    MD5('desc-neft-magnatepoint-salary'), 'ops', NULL
)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 6. Reversal / Transfer Rules
-- Map to: transfers_in (for REV-UPI reversals)
-- ============================================================================

-- UPI Reversals (account 50100154236544)
INSERT INTO spendsense.merchant_rules (
    priority, applies_to, pattern_regex, category_code, subcategory_code, active, pattern_hash, source, tenant_id
)
VALUES (
    10, 'description', 'REV-UPI-50100154236544-', 'transfers_in', NULL, TRUE,
    MD5('desc-rev-upi-50100154236544'), 'ops', NULL
)
ON CONFLICT DO NOTHING;

-- Generic UPI reversal pattern
INSERT INTO spendsense.merchant_rules (
    priority, applies_to, pattern_regex, category_code, subcategory_code, active, pattern_hash, source, tenant_id
)
VALUES (
    10, 'description', 'REV-UPI-', 'transfers_in', NULL, TRUE,
    MD5('desc-rev-upi-generic'), 'ops', NULL
)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 7. Test Transaction Rule (optional - can be ignored or mapped)
-- ============================================================================

-- Test transactions (can be mapped to transfers_in or left uncategorized)
INSERT INTO spendsense.merchant_rules (
    priority, applies_to, pattern_regex, category_code, subcategory_code, active, pattern_hash, source, tenant_id
)
VALUES (
    5, 'description', 'TEST\s+TRANSACTION', 'transfers_in', NULL, TRUE,
    MD5('desc-test-transaction'), 'ops', NULL
)
ON CONFLICT DO NOTHING;

COMMIT;

-- ============================================================================
-- Summary:
-- - Added 15+ merchant rules covering:
--   - 8 PAN shop personal UPI names + 1 pattern rule
--   - 4 credit card payment rules (CRED, HDFC BillPay variants, Amex)
--   - 1 personal loan EMI rule (Razorpay)
--   - 1 mutual fund rule (NSE Clearing)
--   - 1 salary rule (NEFT from MAGNATEPOINT)
--   - 2 reversal rules (specific account + generic)
--   - 1 test transaction rule
-- ============================================================================

