-- =========================================================
-- Merchant Rules Complete Migration
-- Combines: 012_add_merchant_rules_scoping.sql, 015_india_seed_merchant_rules.sql, 022_add_cafe_merchant_rules.sql
-- Adds merchant rules scoping, India-specific seed rules, and cafe rules
-- =========================================================

BEGIN;

-- =============================
-- PART 1: Add user/tenant scoping and pattern hash to merchant_rules
-- =============================

-- Step 1: Add new columns (if not exists)
ALTER TABLE spendsense.merchant_rules
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS tenant_id uuid,
  ADD COLUMN IF NOT EXISTS source varchar(16) DEFAULT 'seed', -- 'learned' | 'seed' | 'ops'
  ADD COLUMN IF NOT EXISTS notes text,
  ADD COLUMN IF NOT EXISTS pattern_hash char(40);

-- Step 2: Update existing rules to have source='seed' and pattern_hash
UPDATE spendsense.merchant_rules
SET source = 'seed'
WHERE source IS NULL OR source = '';

-- Step 3: Calculate pattern_hash for existing rows that don't have it
UPDATE spendsense.merchant_rules
SET pattern_hash = encode(digest(pattern_regex, 'sha1'), 'hex')
WHERE pattern_hash IS NULL;

-- Step 4: Handle duplicates - keep the rule with lowest priority (or oldest if same priority)
-- Deactivate duplicate rules (keep only one active per pattern_hash)
WITH duplicates AS (
  SELECT 
    rule_id,
    ROW_NUMBER() OVER (
      PARTITION BY 
        coalesce(tenant_id, '00000000-0000-0000-0000-000000000000'::uuid),
        applies_to,
        pattern_hash
      ORDER BY priority ASC, created_at ASC
    ) as rn
  FROM spendsense.merchant_rules
  WHERE active = true
  AND pattern_hash IS NOT NULL
)
UPDATE spendsense.merchant_rules
SET active = false
FROM duplicates
WHERE merchant_rules.rule_id = duplicates.rule_id
AND duplicates.rn > 1;

-- Step 5: Add index for tenant/applies_to lookups
CREATE INDEX IF NOT EXISTS ix_rules_scope 
ON spendsense.merchant_rules(tenant_id, applies_to, active);

-- Step 6: Add pattern hash unique index for deduplication (per tenant + applies_to + hash)
-- Drop existing index if it exists (in case of previous failed migration)
DROP INDEX IF EXISTS spendsense.ux_rules_hash;

CREATE UNIQUE INDEX ux_rules_hash
ON spendsense.merchant_rules (
  coalesce(tenant_id, '00000000-0000-0000-0000-000000000000'::uuid),
  applies_to,
  pattern_hash
)
WHERE active = true;

COMMENT ON COLUMN spendsense.merchant_rules.created_by IS 'User who created this rule (for learned rules)';
COMMENT ON COLUMN spendsense.merchant_rules.tenant_id IS 'Optional tenant isolation (NULL = global rule)';
COMMENT ON COLUMN spendsense.merchant_rules.source IS 'Rule source: learned (from edits), seed (initial data), ops (manual)';
COMMENT ON COLUMN spendsense.merchant_rules.pattern_hash IS 'SHA1 hash of pattern_regex for efficient deduplication';

-- Helpful index (if not already exists)
CREATE INDEX IF NOT EXISTS ix_rules_active_pri
ON spendsense.merchant_rules (active, priority);

-- =============================
-- PART 2: India Seed Rules (priority: lower number = stronger match)
-- =============================

-- Note: Categories and subcategories are validated by the cleanup queries below
-- No need to check for specific categories as we'll deactivate invalid ones

-- Clean up any existing rules with invalid category codes first
UPDATE spendsense.merchant_rules
SET active = false
WHERE category_code IS NOT NULL
  AND category_code NOT IN (SELECT category_code FROM spendsense.dim_category);

-- Clean up any existing rules with invalid subcategory codes
UPDATE spendsense.merchant_rules
SET active = false
WHERE subcategory_code IS NOT NULL
  AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory);

-- ---------- TRANSPORT / MOBILITY ----------

-- Auto/Taxi
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 25, 'merchant', '(?i)\b(OLA|UBER|MERU|RAPIDO)\b', 'transport', 'tr_apps', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Metro / Local
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 40, 'description', '(?i)\b(METRO|MMTS|LOCAL TRAIN|TSRTC|BMTC|BEST)\b', 'transport', 'tr_public', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- FASTag / Tolls
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 30, 'description', '(?i)\b(FASTAG|NHAI|TOLL)\b', 'transport', 'tr_tolls', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Fuel Brands
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 25, 'merchant', '(?i)\b(HPCL|BPCL|IOCL|INDIAN\s*OIL|SHELL|RELIANCE)\b', 'transport', 'tr_fuel', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- EATING OUT & NIGHTLIFE ----------

-- Food delivery
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 20, 'merchant', '(?i)\b(SWIGGY|ZOMATO|EATSURE)\b', 'food_dining', 'fd_online', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Cafés/Bakeries
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 35, 'merchant', '(?i)\b(STARBUCKS|CCD|CHAITALI|BAKERY|CAFE|COFFEE)\b', 'food_dining', 'fd_cafes', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Bars/Pubs/Nightlife (incl. Wine Shops)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 28, 'merchant', '(?i)\b(BAR|PUB|BREWERY|LOUNGE|WINE\s*SHOP|LIQUOR)\b', 'food_dining', 'fd_pubs_bars', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Street food / Pan shop cues (description often has PAN/BEEDA/PAAN)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 45, 'description', '(?i)\b(PA[AN]N?|BEEDA|PAN\s*SHOP|BIRIYANI\s*CART|TEA\s*STALL|DOS[A|E]\s*CART|BANDI)\b', 'food_dining', 'fd_pan_shop', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Restaurants (generic)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 38, 'description', '(?i)\b(RESTAURANT|HOTEL|DINING|BIRYANI|TANDOORI|BAKESHOP|MESS)\b', 'food_dining', 'fd_fine', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- GROCERIES / KIRANA ----------

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 22, 'merchant', '(?i)\b(DMART|MORE\s*SUPERMARKET|SPENCERS|RELIANCE\s*SMART)\b', 'groceries', 'groc_hyper', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Quick commerce
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 22, 'merchant', '(?i)\b(ZEPTO|BLINKIT|BIGBASKET|BBNOW)\b', 'groceries', 'groc_online', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Kirana / generic store words
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 47, 'merchant', '(?i)\b(KIRANA|PROVISION|GENERAL\s*STORE|SUPER\s*MART|BAZAR|DEPARTMENTAL)\b', 'groceries', 'groc_hyper', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- SHOPPING / APPAREL / ELECTRONICS ----------

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 24, 'merchant', '(?i)\b(AMAZON|FLIPKART|AJIO|MYNTRA|NYKAA|MEESHO)\b', 'shopping', 'shop_marketplaces', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 26, 'merchant', '(?i)\b(CROMA|RELIANCE\s*DIGITAL|VIJAY\s*SALES)\b', 'shopping', 'shop_electronics', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Small businesses (fallback)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 60, 'merchant', '(?i)(ENTERPRISES?|TRAD(?:ER|ING)S?|STORES?|MART|BAZAR|BOUTIQUE)$', 'shopping', 'shop_general', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- MOBILE / INTERNET / DTH ----------

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 23, 'merchant', '(?i)\b(AIRTEL|JIO|VI\b|VODAFONE|IDEA)\b', 'utilities', 'util_mobile', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 23, 'merchant', '(?i)\b(JIOFIBER|ACT\s*FIBERNET|HATHWAY|BSNL\s*(FTTH|BB)|TIKONA)\b', 'utilities', 'util_broadband', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 33, 'merchant', '(?i)\b(TATA\s*PLAY|AIRTEL\s*DTH|SUN\s*DIRECT|DISHTV)\b', 'utilities', 'util_dth_cable', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- UTILITIES ----------

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 30, 'merchant', '(?i)\b(BSES\s*(RAJDHANI|YAMUNA)|TPDDL|TSSPDCL|MSEDCL|BESCOM|TANGEDCO|APDCL)\b', 'utilities', 'util_electricity', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 32, 'merchant', '(?i)\b(IGL|MGL|ADANI\s*GAS|PNG)\b', 'utilities', 'util_gas_lpg', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- HEALTHCARE ----------

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 35, 'merchant', '(?i)\b(APOLLO\s*(PHARMACY|HOSPITALS)|FORTIS|MANIPAL|STAR\s*HEALTH|MEDPLUS)\b', 'medical', 'med_general', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 35, 'merchant', '(?i)\b(MEDPLUS|PHARMACY|APOLLO\s*PHARMACY)\b', 'medical', 'med_pharma', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 35, 'merchant', '(?i)\b(THYROCARE|LAL\s*PATH|DR\.?\s*LAL)\b', 'medical', 'med_other', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- EDUCATION ----------

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 42, 'description', '(?i)\b(SCHOOL\s*FEE|TUTION|TUITION|COACHING)\b', 'education', 'edu_tuition', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- INSURANCE ----------

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 30, 'merchant', '(?i)\b(LIC|HDFC\s*LIFE|SBI\s*LIFE|ICICI\s*LOMBARD|ACKO|STAR\s*HEALTH|HDFC\s*ERGO)\b', 'insurance_premiums', 'ins_life', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- LOANS / EMI / CREDIT CARD BILLS ----------

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 22, 'description', '(?i)\b(CREDIT\s*CARD\s*BILL|CARD\s*PAYMENT|CC\s*PAYMENT)\b', 'loans_payments', 'loan_cc_bill', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 28, 'description', '(?i)\b(EMI\s*DEBIT|LOAN\s*EMI|AUTO\s*DEBIT)\b', 'loans_payments', 'loan_personal', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- FEES / TAX ----------

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 38, 'description', '(?i)\b(BANK\s*CHARGE|CONVENIENCE\s*FEE|IMPS\s*CHARGES|UPI\s*CHARGE)\b', 'banks', 'bank_charges', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 38, 'description', '(?i)\b(INCOME\s*TAX|TDS|GST\s*PAYMENT|EPFO)\b', 'govt_tax', 'tax_income', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- INCOME ----------

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 18, 'description', '(?i)\b(SALARY\s*(CREDIT|PAY)|PAYROLL|NEFT\s*CREDIT.*SALARY)\b', 'income', 'inc_salary', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 30, 'description', '(?i)\b(REFUND|CASHBACK|REVERSAL)\b', 'income', 'inc_other', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- =============================
-- PART 3: Add Cafe/Restaurant Merchant Rules
-- =============================

-- Add cafe/coffee shop keywords
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 35, 'merchant', '(?i)\b(CUP|COFFEE|THEORY|CAFE|COFFEE SHOP|BARISTA)\b', 'food_dining', 'fd_cafes', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- Add more cafe keywords
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 36, 'merchant', '(?i)\b(BIG CUP|CUP THEORY|COFFEE.*THEORY)\b', 'food_dining', 'fd_cafes', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- =============================
-- PART 4: Add Home Services / Urban Company
-- =============================

-- Urban Company (home services: cleaning, plumbing, salon, etc.)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 25, 'merchant', '(?i)\b(URBAN\s*COMPANY|URBANCOMPANY|UC)\b', 'shopping', 'shop_home_kitchen', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- =============================
-- PART 5: Add Merchant Rules for User Corrections
-- =============================

-- Interest Paid (description-based rule for bank interest received)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 20, 'description', '(?i)\b(INTEREST\s*PAID|INTEREST\s*CREDIT|INTEREST\s*RECEIVED)\b', 'banks', 'bank_interest', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- Kisetsusaisonfinan (personal loan deposit from company - income)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 25, 'merchant', '(?i)\b(KISETSU\s*SAISON\s*FINAN|KISETSUSAISONFINAN)\b', 'income', 'inc_other', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- American Express (credit card payment)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 22, 'merchant', '(?i)\b(AMERICAN\s*EXPRESS|AMEX)\b', 'loans_payments', 'loan_cc_bill', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- Vijetha (groceries - supermarket)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 25, 'merchant', '(?i)\b(VIJETHA)\b', 'groceries', 'groc_hyper', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- Marichi Hotels (pubs & bars)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 25, 'merchant', '(?i)\b(MARICHI\s*HOTELS|MARICHIHOTELS)\b', 'food_dining', 'fd_pubs_bars', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- Allvet Pet Clinic (vet services)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 25, 'merchant', '(?i)\b(ALLVET\s*PET\s*CLINIC|ALLVETPETCLINIC)\b', 'pets', 'pet_vaccine', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- PRS Fresh Chicken (meat)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 25, 'merchant', '(?i)\b(PRS\s*FRESH\s*CHICKEN|PRSFRESHCHICKEN)\b', 'groceries', 'groc_meat', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- BPCL Premium Fuels (fuel/diesel)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 22, 'merchant', '(?i)\b(BPCL\s*PREMIUM\s*FUELS?|BPCL|BHARAT\s*PETROLEUM)\b', 'transport', 'tr_fuel', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- Hotel Crown Pan Shop (pan shop)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 25, 'merchant', '(?i)\b(HOTEL\s*CROWN\s*PAN\s*SHOP|CROWN\s*PAN)\b', 'food_dining', 'fd_pan_shop', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- Razorpay Software Private (loan EMI)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 22, 'merchant', '(?i)\b(RAZORPAY\s*SOFTWARE|RAZORPAYSOFTWAREPRIV)\b', 'loans_payments', 'loan_personal', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- Fondof Coffee Lounge (coffee/cafes)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 25, 'merchant', '(?i)\b(FONDOF\s*COFFEE\s*LOUNGE|FONDOFCOFFEELOUNGE)\b', 'food_dining', 'fd_cafes', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- =============================
-- PART 6: Add Additional Merchant Rules for User Corrections
-- =============================

-- Commissioner Of Poli - traffic police challan
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 25, 'merchant', '(?i)\b(COMMISSIONER\s*OF\s*POLI|COMMISSIONER\s*OF\s*POLICE)\b', 'govt_tax', 'tax_other', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- Slice - loan emi
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 22, 'merchant', '(?i)\b(SLICE)\b', 'loans_payments', 'loan_personal', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- Raghava Vivek Koripalli - p2p transfer
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 8, 'merchant', '(?i)\b(RAGHAVA\s*VIVEK\s*KORIPALLI|RAGHAVAVIVEKKORIPALLI)\b', 'transfers_out', 'tr_out_wallet', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 8, 'description', '(?i)\b(RAGHAVA\s*VIVEK\s*KORIPALLI|RAGHAVAVIVEKKORIPALLI)\b', 'transfers_out', 'tr_out_wallet', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- IMPS transfers with personal names (P2P pattern)
-- Matches IMPS transactions with personal names in description
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 10, 'description', '(?i)\bIMPS.*SATYA\s*SRINIVASA\s*RAVI\s*BABU\b', 'transfers_out', 'tr_out_wallet', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- Congressional The Be - shopping/apparel
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 25, 'merchant', '(?i)\b(CONGRESSIONAL\s*THE\s*BE|CONGRESSIONALTHEBE)\b', 'shopping', 'shop_clothing', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 25, 'description', '(?i)\b(CONGRESSIONAL\s*THE\s*BE|CONGRESSIONALTHEBE)\b', 'shopping', 'shop_clothing', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- United Blowpast Cont - business expenses
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 25, 'merchant', '(?i)\b(UNITED\s*BLOWPAST\s*CONT|UNITEDBLOWPASTCONT)\b', 'business_expenses', 'biz_other', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 25, 'description', '(?i)\b(UNITED\s*BLOWPAST\s*CONT|UNITEDBLOWPASTCONT)\b', 'business_expenses', 'biz_other', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- IDFC First Bank - credit card payment
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 22, 'merchant', '(?i)\b(IDFC\s*FIRST\s*BANK|IDFCFIRST|IDFC\s*FIRST)\b', 'loans_payments', 'loan_cc_bill', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 22, 'description', '(?i)\b(IDFC\s*FIRST\s*BANK|IDFCFIRST|IDFC\s*FIRST)\b', 'loans_payments', 'loan_cc_bill', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- HDFC Credit Card Payment patterns (Bhdfu4f0h84ogq/Billdkhdfccard)
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 10, 'description', '(?i)\b(BHDFU4F0H84OGQ|BILLDKHDFCCARD)\b', 'loans_payments', 'loan_cc_bill', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 10, 'description', '(?i)\bBILL.*HDFC.*CARD\b', 'loans_payments', 'loan_cc_bill', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

-- Orange Auto Private - motor and maintenance
INSERT INTO spendsense.merchant_rules (rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by, created_at)
VALUES 
    (gen_random_uuid(), 25, 'merchant', '(?i)\b(ORANGE\s*AUTO\s*PRIVATE|ORANGEAUTOPRIVATE|ORANGE\s*AUTO)\b', 'motor_maintenance', 'motor_services', true, 'seed', NULL, NULL, now()),
    (gen_random_uuid(), 25, 'description', '(?i)\b(ORANGE\s*AUTO\s*PRIVATE|ORANGEAUTOPRIVATE|ORANGE\s*AUTO)\b', 'motor_maintenance', 'motor_services', true, 'seed', NULL, NULL, now())
ON CONFLICT DO NOTHING;

COMMIT;

