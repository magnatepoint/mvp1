-- ============================================================================
-- Taxonomy Complete Migration
-- Consolidates: 028, 029, 030_fix, 031, 032, 034, 035, 036_add_default_subcategories
-- Creates normalized category/subcategory tables, migrates data, fixes taxonomy,
-- seeds merchants and rules, deactivates old rules, and adds default subcategories
-- Idempotent: safe to run multiple times
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1) Schema: Create normalized category and subcategory tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS spendsense.category (
  id          BIGSERIAL PRIMARY KEY,
  code        TEXT NOT NULL UNIQUE,              -- stable programmatic key: e.g., INCOME, TRANSFER_IN
  name        TEXT NOT NULL,                     -- human readable
  budget_bucket TEXT,                            -- e.g., "Inflows", "Mandatory Payments (Out-Flow-1)"
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS spendsense.subcategory (
  id           BIGSERIAL PRIMARY KEY,
  category_id  BIGINT NOT NULL REFERENCES spendsense.category(id) ON DELETE CASCADE,
  code         TEXT NOT NULL,
  name         TEXT NOT NULL,
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (category_id, code)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_subcategory_category_id ON spendsense.subcategory(category_id);
CREATE INDEX IF NOT EXISTS idx_subcategory_code ON spendsense.subcategory(code);
CREATE INDEX IF NOT EXISTS idx_category_code ON spendsense.category(code);

-- ============================================================================
-- 2) Triggers: Auto-update updated_at
-- ============================================================================
-- Reuse existing function or create if it doesn't exist
CREATE OR REPLACE FUNCTION spendsense.tg_set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

DO $$
BEGIN
  -- Check if trigger already exists (schema-aware check)
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'spendsense' 
      AND c.relname = 'category'
      AND t.tgname = 'category_set_updated_at'
  ) THEN
    CREATE TRIGGER category_set_updated_at
      BEFORE UPDATE ON spendsense.category
      FOR EACH ROW EXECUTE FUNCTION spendsense.tg_set_updated_at();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'spendsense' 
      AND c.relname = 'subcategory'
      AND t.tgname = 'subcategory_set_updated_at'
  ) THEN
    CREATE TRIGGER subcategory_set_updated_at
      BEFORE UPDATE ON spendsense.subcategory
      FOR EACH ROW EXECUTE FUNCTION spendsense.tg_set_updated_at();
  END IF;
END$$;

-- ============================================================================
-- 3) Seed Categories (UPSERT)
-- ============================================================================

WITH upsert_cat AS (
  INSERT INTO spendsense.category (code, name, budget_bucket)
  VALUES
    ('INCOME','INCOME','Inflows'),
    ('TRANSFER_IN','TRANSFER_IN','Inflows'),
    ('TRANSFER_OUT','TRANSFER_OUT', 'Outflows'),
    ('LOAN_PAYMENTS','LOAN_PAYMENTS','Mandatory Payments (Out-Flow-1)'),
    ('UTILITIES','UTILITIES','Mandatory Payments (Out-Flow-2)'),
    ('RENT','RENT','Mandatory Payments (Out-Flow-2)'),
    ('BANK_FEES','BANK_FEES','Mandatory Payments (Out-Flow-2)'),
    ('ENTERTAINMENT','ENTERTAINMENT','Luxury Payments (Out-Flow-3)'),
    ('DINING','DINING','Luxury Payments (Out-Flow-4)'),
    ('GROCERIES','Groceries','Necessities'),
    ('HOME_IMPROVEMENT','HOME_IMPROVEMENT','House Maintenance (Out-Flow-5)'),
    ('MEDICAL','MEDICAL','Medical Payments (Out-Flow-6)'),
    ('PERSONAL_CARE','PERSONAL_CARE','Personal Payments (Out-Flow-7)'),
    ('GOVERNMENT_AND_NON_PROFIT','GOVERNMENT_AND_NON_PROFIT','IT savings (Out-Flow-8)'),
    ('TRANSPORTATION','TRANSPORTATION','Local Transport Payments (Out-Flow-9)'),
    ('TRAVEL','TRAVEL','Travel Payments (Out-Flow-10)'),
    ('GENERAL_MERCHANDISE','GENERAL_MERCHANDISE','GENERAL MERCHANDISE (Out-Flow-11)'),
    ('GENERAL_SERVICES','GENERAL_SERVICES','Miscellaneous Payments (Out-Flow-12)'),
    ('SHOPPING','SHOPPING','Shopping Expenses'),
    ('CHILD_CARE','Child Care','Child care expenses'),
    ('MOTOR_MAINTENANCE','Motor Maintaince','Motor Maintaince'),
    ('PETS','Pets','Pet Maintaince'),
    ('ASSETS_LIABILITIES','Assets & Liabilities','Balance Sheet')
  ON CONFLICT (code) DO UPDATE
  SET name = EXCLUDED.name,
      budget_bucket = EXCLUDED.budget_bucket,
      updated_at = now()
  RETURNING 1
)
SELECT 1;

-- ============================================================================
-- 4) Seed Subcategories (UPSERT) - Using CTE for category lookups
-- ============================================================================

-- INCOME
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'INCOME')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('DIVIDENDS','DIVIDENDS','Dividends from investment accounts'),
  ('INTEREST_EARNED','INTEREST_EARNED','Income from interest on savings accounts'),
  ('RETIREMENT_PENSION','RETIREMENT_PENSION','Income from pension payments'),
  ('TAX_REFUND','TAX_REFUND','Income from tax refunds'),
  ('UNEMPLOYMENT','UNEMPLOYMENT','Unemployment benefits, including insurance and healthcare'),
  ('WAGES','WAGES (Labour/Job work/salary)','Income from salaries, gig-economy work, and tips'),
  ('OTHER_INCOME','OTHER_INCOME','Other miscellaneous income, including alimony, social security, child support, rental'),
  ('BUSINESS_INCOME','Through -Bussiness','Income from business'),
  ('MARKET_REALIZATION','Through -Stocks and Mutual Funds','Income through selling of stocks and mutual funds')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = now();

-- TRANSFER_IN
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'TRANSFER_IN')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('CASH_ADVANCES_AND_LOANS','CASH_ADVANCES_AND_LOANS','Loans and cash advances deposited into a bank account'),
  ('DEPOSIT','DEPOSIT','Cash, checks, and ATM deposits into a bank account'),
  ('INVESTMENT_AND_RETIREMENT_FUNDS','INVESTMENT_AND_RETIREMENT_FUNDS','Inbound transfers to an investment or retirement account'),
  ('SAVINGS','SAVINGS','Inbound transfers to a savings account'),
  ('SWEEP_IN','Sweep in',''),
  ('ACCOUNT_TRANSFER','ACCOUNT_TRANSFER','General inbound transfers from another account'),
  ('OTHER_TRANSFER_IN','OTHER_TRANSFER_IN','Other miscellaneous inbound transactions')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = now();

-- TRANSFER_OUT
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'TRANSFER_OUT')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('INVESTMENT_AND_RETIREMENT_FUNDS','INVESTMENT_AND_RETIREMENT_FUNDS','Transfers to an investment or retirement account'),
  ('SAVINGS','SAVINGS','Outbound transfers to savings accounts'),
  ('WITHDRAWAL','WITHDRAWAL','Withdrawals from a bank account'),
  ('ACCOUNT_TRANSFER','ACCOUNT_TRANSFER','General outbound transfers to another account'),
  ('SWEEP_OUT','Sweep out',''),
  ('OTHER_TRANSFER_OUT','OTHER_TRANSFER_OUT','Other miscellaneous outbound transactions')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = now();

-- LOAN_PAYMENTS
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'LOAN_PAYMENTS')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('CAR_PAYMENT','LOAN_PAYMENTS_CAR_PAYMENT','Car loans and leases'),
  ('CREDIT_CARD_PAYMENT','LOAN_PAYMENTS_CREDIT_CARD_PAYMENT','Payments to a credit card (positive for credit card subtypes, negative for depository)'),
  ('PERSONAL_LOAN_PAYMENT','LOAN_PAYMENTS_PERSONAL_LOAN_PAYMENT','Personal loans, including cash advances and BNPL repayments'),
  ('MORTGAGE_PAYMENT','LOAN_PAYMENTS_MORTGAGE_PAYMENT','Payments on mortgages'),
  ('STUDENT_LOAN_PAYMENT','LOAN_PAYMENTS_STUDENT_LOAN_PAYMENT','Payments on student loans'),
  ('OTHER_PAYMENT','LOAN_PAYMENTS_OTHER_PAYMENT','Other miscellaneous debt payments')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = now();

-- UTILITIES
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'UTILITIES')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('ELECTRICITY','ELECTRICITY','electricity bills'),
  ('GAS','Gas','Gas bill'),
  ('INTERNET_AND_CABLE','INTERNET_AND_CABLE','Internet and cable bills'),
  ('SEWAGE_AND_WASTE_MANAGEMENT','SEWAGE_AND_WASTE_MANAGEMENT','Sewage and garbage disposal bills'),
  ('MOBILE_TELEPHONE','Mobile/TELEPHONE','Cell phone bills'),
  ('WATER','WATER','Water bills'),
  ('OTHER_UTILITIES','OTHER_UTILITIES','Other miscellaneous utility bills')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = now();

-- RENT
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'RENT')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, 'RENT', 'RENT', 'Rent payment'
FROM c
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- BANK_FEES
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'BANK_FEES')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('ATM_FEES','BANK_FEES_ATM_FEES','Fees incurred for out-of-network ATMs'),
  ('FOREIGN_TRANSACTION_FEES','BANK_FEES_FOREIGN_TRANSACTION_FEES','Fees incurred on non-domestic transactions'),
  ('INSUFFICIENT_FUNDS','BANK_FEES_INSUFFICIENT_FUNDS','Fees relating to insufficient funds'),
  ('INTEREST_CHARGE','BANK_FEES_INTEREST_CHARGE','Interest on purchases or cash advances'),
  ('OVERDRAFT_FEES','BANK_FEES_OVERDRAFT_FEES','Fees incurred when an account is in overdraft'),
  ('OTHER_BANK_FEES','BANK_FEES_OTHER_BANK_FEES','Other miscellaneous bank fees')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- ENTERTAINMENT
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'ENTERTAINMENT')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('CASINOS_AND_GAMBLING','CASINOS_AND_GAMBLING','Gambling, casinos, and sports betting'),
  ('MUSIC_AND_AUDIO','MUSIC_AND_AUDIO','Music purchases and streaming'),
  ('SPORTING_EVENTS','SPORTING_EVENTS','Purchases at sporting events, venues, concerts'),
  ('AMUSEMENT_PARKS','AMUSEMENT_PARKS/ CIRCUS/MAGIC SHOW','Amusement parks, circus, magic shows'),
  ('MUSEUMS','MUSEUMS/ART EXHIBITIONS/','Museums and art exhibitions'),
  ('TV_AND_MOVIES','ENTERTAINMENT_TV_AND_MOVIES','Streaming services and theaters'),
  ('VIDEO_GAMES','ENTERTAINMENT_VIDEO_GAMES','Video games and VR'),
  ('OTHER_ENTERTAINMENT','ENTERTAINMENT_OTHER_ENTERTAINMENT','Night life and other entertainment'),
  ('ADVENTURE_SPORTS','Adventure sports','Skydiving, rock climbing, etc.')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- DINING
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'DINING')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('FAST_FOOD','FastFood Restaurants','Pick-and-go outlets: McDonald''s, KFC'),
  ('FINE_DINING','Fine Dining','Fine dining restaurants'),
  ('CASUAL_DINING','Casual Dining','Ala-carte restaurants'),
  ('BUFFET','Buffet Restaurants','Buffet Restaurants'),
  ('CAFES_BISTROS','Cafes and Bistros','Café lounges'),
  ('PUBS_BARS','Pubs and Bars','Pubs and Bars'),
  ('STREET_FOOD','Street Food','Street Food'),
  ('ONLINE_DELIVERY','Online Delivery','Food delivery like Swiggy, Zomato')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- GROCERIES
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'GROCERIES')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('HYPERMARKETS','HyperMarkets_','Chains like Spar, Lulu, D-Mart'),
  ('SUPERMARKETS','supermarkets_Department stores','Ratnadeep, Vijetha, Spencers'),
  ('MOM_AND_POP','Mom and pop Stores','Neighborhood kirana stores'),
  ('ONLINE_GROCERIES','Online Groceries','Grofers, BigBasket, Swiggy Instamart, Zepto, Blinkit'),
  ('VEG_FRUIT_STORES','Vegetable and fruits Stores','Pure-O-Natural and local fruit/veg vendors')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- HOME_IMPROVEMENT
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'HOME_IMPROVEMENT')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('FURNITURE','FURNITURE','Furniture, bedding, and home accessories'),
  ('HARDWARE','HARDWARE','Building materials, paint, wallpaper'),
  ('REPAIR_AND_MAINTENANCE','REPAIR_AND_MAINTENANCE','Plumbing, lighting, gardening, roofing'),
  ('SECURITY','SECURITY','Home security systems'),
  ('OTHER_HOME_IMPROVEMENT','OTHER_HOME_IMPROVEMENT','Pool installation, pest control, etc.')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- MEDICAL
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'MEDICAL')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('DENTAL_CARE','DENTAL_CARE','Dentists and dental care'),
  ('EYE_CARE','EYE_CARE','Optometrists, contacts, glasses'),
  ('NURSING_CARE','NURSING_CARE','Nursing care and facilities'),
  ('PHARMACIES_AND_SUPPLEMENTS','PHARMACIES_AND_SUPPLEMENTS','Pharmacies and nutrition shops'),
  ('PRIMARY_CARE','PRIMARY_CARE','Doctors and physicians'),
  ('MEDICAL_APPS','Medical APPs','Medical app payments'),
  ('OTHER_MEDICAL','OTHER_MEDICAL','Hospitals, blood work, ambulances')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- PERSONAL_CARE
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'PERSONAL_CARE')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('GYMS_AND_FITNESS_CENTERS','GYMS_AND_FITNESS_CENTERS','Gyms, fitness centers, workout classes'),
  ('HAIR_AND_SKIN_SERVICES','HAIR_AND_SKin SERVICES','Salon, spa/massage, grooming'),
  ('BEAUTY_PRODUCTS','Hair,skin, beauty and personal  Products','Bath, beauty & personal products'),
  ('LAUNDRY_AND_DRY_CLEANING','LAUNDRY_AND_DRY_CLEANING','Wash & fold, dry cleaning'),
  ('OTHER_PERSONAL_CARE','OTHER_PERSONAL_CARE','Other personal care, mental health apps/services')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- GOVERNMENT_AND_NON_PROFIT
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'GOVERNMENT_AND_NON_PROFIT')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('DONATIONS','DONATIONS','Charitable, political, and religious donations'),
  ('DEPARTMENTS_AND_AGENCIES','GOVERNMENT_DEPARTMENTS_AND_AGENCIES','Licenses, passport renewal'),
  ('TAX_PAYMENT','TAX_PAYMENT','Income and property taxes'),
  ('OTHER_GOV_NONPROFIT','OTHER_GOVERNMENT_AND_NON_PROFIT','Other government & non-profit payments')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- TRANSPORTATION
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'TRANSPORTATION')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('BIKES_AND_SCOOTERS','BIKES_AND_SCOOTERS','Bike and scooter rentals'),
  ('DIGITAL_APPS','TRANSPORATION_ DIGITAL_APPS','Ride apps: Uber, Ola'),
  ('PARKING','PARKING','Parking fees'),
  ('PUBLIC_TRANSIT','PUBLIC_TRANSIT','Rail, metro, bus'),
  ('TAXIS_AND_RIDE_SHARES','TAXIS_AND_RIDE_SHARES','Taxi and ride share'),
  ('TOLLS','TOLLS','Toll expenses'),
  ('OTHER_TRANSPORTATION','OTHER_TRANSPORTATION','Other transportation expenses')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- TRAVEL
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'TRAVEL')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('TRAVEL_FLIGHTS','TRAVEL_FLIGHTS','Airline expenses'),
  ('TRAVEL_LODGING','TRAVEL_LODGING','Hotels, motels, Airbnb'),
  ('TRAVEL_RENTAL_CARS','TRAVEL_RENTAL_CARS','Rental cars, charter buses, trucks'),
  ('TRAVEL_OTHER','TRAVEL_OTHER_TRAVEL','Other travel expenses')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- GENERAL_MERCHANDISE
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'GENERAL_MERCHANDISE')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('BOOKSTORES_AND_NEWSSTANDS','BOOKSTORES_AND_NEWSSTANDS','Books, magazines, news'),
  ('GIFTS_AND_NOVELTIES','GIFTS_AND_NOVELTIES','Photo, gifts, cards, florists'),
  ('OFFICE_SUPPLIES','OFFICE_SUPPLIES','Office goods'),
  ('ONLINE_MARKETPLACES','ONLINE_MARKETPLACES','Etsy, Ebay, Amazon'),
  ('SPORTING_GOODS','SPORTING_GOODS','Sporting goods, camping, outdoor'),
  ('SUPERSTORES','SUPERSTORES','Target, Walmart (groceries + general)'),
  ('TOBACCO_AND_VAPE','TOBACCO_AND_VAPE','Tobacco & vaping'),
  ('OTHER_GENERAL_MERCHANDISE','OTHER_GENERAL_MERCHANDISE','Toys, hobbies, arts & crafts')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- GENERAL_SERVICES
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'GENERAL_SERVICES')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('ACCOUNTING_AND_FINANCIAL_PLANNING','ACCOUNTING_AND_FINANCIAL_PLANNING','Financial planning, tax & accounting'),
  ('CONSULTING_AND_LEGAL','CONSULTING_AND_LEGAL','Consulting and legal services'),
  ('POSTAGE_AND_SHIPPING','POSTAGE_AND_SHIPPING','Mail, packaging, shipping'),
  ('STORAGE','STORAGE','Storage services & facilities'),
  ('OTHER_GENERAL_SERVICES','OTHER_GENERAL_SERVICES','Advertising, cloud storage, misc.')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- SHOPPING
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'SHOPPING')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('CLOTHING_AND_ACCESSORIES','CLOTHING_AND_ACCESSORIES','Apparel, shoes, jewelry (Investment)'),
  ('CONVENIENCE_STORES','CONVENIENCE_STORES','Purchases at convenience stores'),
  ('DEPARTMENT_STORES','DEPARTMENT_STORES','Retail—clothing & home goods'),
  ('DISCOUNT_STORES','DISCOUNT_STORES','Discount retailers'),
  ('ELECTRONICS','ELECTRONICS','Electronics stores & sites'),
  ('ONLINE_SHOPPING','Online shopping','Personal, household, toys, auto, books, media, home, kitchen; Amazon/Flipkart etc.')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- CHILD_CARE
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'CHILD_CARE')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('EDUCATION','Education','School/tuition fee for children'),
  ('CHILD_CARE_EXPENSES','Child care expenses','Day care and child care needs')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- MOTOR_MAINTENANCE
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'MOTOR_MAINTENANCE')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('AUTOMOTIVE_SERVICES','GENERAL_SERVICES_AUTOMOTIVE','Oil changes, washes, repairs, towing'),
  ('INSURANCE','GENERAL_SERVICES_INSURANCE','Auto insurance')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- PETS
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'PETS')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('GROOMING','Grooming','Grooming, boarding, bathing'),
  ('PET_FOOD','Pet Food Expenses','Pet Food Expenses'),
  ('VACCINATION','Vaccination','Pet vaccination expenses'),
  ('INSURANCE','Insurance','Pet insurance')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- ASSETS & LIABILITIES (Balance Sheet style)
WITH c AS (SELECT id, code FROM spendsense.category WHERE code = 'ASSETS_LIABILITIES')
INSERT INTO spendsense.subcategory (category_id, code, name, description)
SELECT c.id, sc.code, sc.name, sc.description
FROM c
JOIN (VALUES
  ('CASH_IN_HAND_FD','Cash in Hand-FD','Cash / Fixed deposits'),
  ('INVESTMENTS_IN_FM','Investments in FM','Financial market investments'),
  ('HOUSE','House','Residential property (asset)'),
  ('GOLD','Gold','Gold holdings (asset)'),
  ('REAL_ESTATE','Real Estate','Real estate assets'),
  ('CAR','Car','Vehicle (asset)'),
  ('PERSONAL_LOAN','Personal Loan','Outstanding personal loan (liability)'),
  ('HOME_LOAN','Home Loan','Outstanding home loan (liability)'),
  ('CAR_LOAN','Car Loan','Outstanding car loan (liability)'),
  ('CREDIT_CARD_DEBT','Credit card debt','Credit card outstanding (liability)'),
  ('OTHER_LIABILITIES','other Liabilities','Other liabilities')
) AS sc(code,name,description) ON TRUE
ON CONFLICT (category_id, code) DO UPDATE
SET name = EXCLUDED.name, description = EXCLUDED.description, updated_at = now();

-- ============================================================================
-- 5) Helper View: Convenient view for admin UIs and queries
-- ============================================================================

CREATE OR REPLACE VIEW spendsense.v_categories AS
SELECT
  c.id              AS category_id,
  c.code            AS category_code,
  c.name            AS category_name,
  c.budget_bucket,
  s.id              AS subcategory_id,
  s.code            AS subcategory_code,
  s.name            AS subcategory_name,
  s.description
FROM spendsense.category c
LEFT JOIN spendsense.subcategory s ON s.category_id = c.id
ORDER BY c.name, s.name;

COMMENT ON VIEW spendsense.v_categories IS 'Convenient view joining categories and subcategories with all fields';

COMMIT;

-- ============================================================================
-- Migration complete
-- ============================================================================
-- This migration creates normalized category/subcategory tables with:
-- - Stable codes (UPPER_SNAKE_CASE) for programmatic access
-- - Human-readable names
-- - Budget buckets for grouping
-- - Descriptions for subcategories
-- - Idempotent UPSERT logic (safe to rerun)
-- ============================================================================

-- ============================================================================
-- Migrate category/subcategory data to dim_category/dim_subcategory
-- Drops duplicate tables and migrates all data to existing schema
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1) Add budget_bucket and description columns if they don't exist
-- ============================================================================
ALTER TABLE spendsense.dim_category 
  ADD COLUMN IF NOT EXISTS budget_bucket TEXT;

ALTER TABLE spendsense.dim_subcategory 
  ADD COLUMN IF NOT EXISTS description TEXT;

-- ============================================================================
-- 2) Map budget_bucket to txn_type for categories
-- ============================================================================
-- Helper function to determine txn_type from budget_bucket
CREATE OR REPLACE FUNCTION spendsense.map_budget_bucket_to_txn_type(bucket TEXT)
RETURNS VARCHAR(12) AS $$
BEGIN
  RETURN CASE
    WHEN bucket ILIKE '%Inflow%' THEN 'income'
    WHEN bucket ILIKE '%Mandatory%' OR bucket ILIKE '%Necessities%' THEN 'needs'
    WHEN bucket ILIKE '%Luxury%' OR bucket ILIKE '%Shopping%' OR bucket ILIKE '%Entertainment%' THEN 'wants'
    WHEN bucket ILIKE '%Balance Sheet%' OR bucket ILIKE '%Asset%' THEN 'assets'
    ELSE 'wants' -- default
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- 3) Migrate categories to dim_category
-- ============================================================================
-- Deduplicate categories first (in case of duplicates)
INSERT INTO spendsense.dim_category (category_code, category_name, txn_type, display_order, active, budget_bucket)
SELECT DISTINCT ON (LOWER(code))
  LOWER(code) AS category_code,
  name AS category_name,
  spendsense.map_budget_bucket_to_txn_type(budget_bucket) AS txn_type,
  -- Assign display_order based on category type
  CASE 
    WHEN code = 'INCOME' THEN 5
    WHEN code = 'TRANSFER_IN' THEN 6
    WHEN code = 'TRANSFER_OUT' THEN 7
    WHEN code = 'LOAN_PAYMENTS' THEN 90
    WHEN code = 'UTILITIES' THEN 10
    WHEN code = 'RENT' THEN 20
    WHEN code = 'BANK_FEES' THEN 15
    WHEN code = 'GROCERIES' THEN 30
    WHEN code = 'DINING' THEN 40
    WHEN code = 'ENTERTAINMENT' THEN 50
    WHEN code = 'SHOPPING' THEN 60
    WHEN code = 'TRANSPORTATION' THEN 70
    WHEN code = 'TRAVEL' THEN 75
    WHEN code = 'MEDICAL' THEN 25
    WHEN code = 'PERSONAL_CARE' THEN 45
    WHEN code = 'HOME_IMPROVEMENT' THEN 35
    WHEN code = 'GOVERNMENT_AND_NON_PROFIT' THEN 80
    WHEN code = 'GENERAL_MERCHANDISE' THEN 65
    WHEN code = 'GENERAL_SERVICES' THEN 85
    WHEN code = 'CHILD_CARE' THEN 28
    WHEN code = 'MOTOR_MAINTENANCE' THEN 72
    WHEN code = 'PETS' THEN 55
    WHEN code = 'ASSETS_LIABILITIES' THEN 100
    ELSE 100
  END AS display_order,
  TRUE AS active,
  budget_bucket
FROM spendsense.category
ORDER BY LOWER(code), id
ON CONFLICT (category_code) DO UPDATE SET
  category_name = EXCLUDED.category_name,
  txn_type = EXCLUDED.txn_type,
  display_order = EXCLUDED.display_order,
  active = TRUE,
  budget_bucket = EXCLUDED.budget_bucket;

-- ============================================================================
-- 4) Migrate subcategories to dim_subcategory
-- ============================================================================
-- Deduplicate subcategories first, then insert with proper display_order
INSERT INTO spendsense.dim_subcategory (subcategory_code, category_code, subcategory_name, display_order, active, description)
WITH deduped_subcats AS (
  SELECT DISTINCT ON (LOWER(s.code))
    LOWER(s.code) AS subcategory_code,
    LOWER(c.code) AS category_code,
    s.name AS subcategory_name,
    s.description,
    s.id
  FROM spendsense.subcategory s
  JOIN spendsense.category c ON s.category_id = c.id
  ORDER BY LOWER(s.code), s.id
)
SELECT 
  subcategory_code,
  category_code,
  subcategory_name,
  -- Assign display_order sequentially within each category
  ROW_NUMBER() OVER (PARTITION BY category_code ORDER BY subcategory_code) * 10 AS display_order,
  TRUE AS active,
  description
FROM deduped_subcats
ON CONFLICT (subcategory_code) DO UPDATE SET
  category_code = EXCLUDED.category_code,
  subcategory_name = EXCLUDED.subcategory_name,
  display_order = EXCLUDED.display_order,
  active = TRUE,
  description = EXCLUDED.description;

-- ============================================================================
-- 5) Update view to use dim_category/dim_subcategory
-- ============================================================================
-- Drop existing view first (in case column names differ)
DROP VIEW IF EXISTS spendsense.v_categories;

CREATE VIEW spendsense.v_categories AS
SELECT
  dc.category_code,
  dc.category_name,
  dc.txn_type,
  dc.budget_bucket,
  dc.display_order AS category_display_order,
  dc.active AS category_active,
  ds.subcategory_code,
  ds.subcategory_name,
  ds.description,
  ds.display_order AS subcategory_display_order,
  ds.active AS subcategory_active
FROM spendsense.dim_category dc
LEFT JOIN spendsense.dim_subcategory ds ON ds.category_code = dc.category_code
ORDER BY dc.display_order, ds.display_order;

COMMENT ON VIEW spendsense.v_categories IS 'Convenient view joining dim_category and dim_subcategory with all fields';

-- ============================================================================
-- 6) Drop duplicate tables (if they exist)
-- ============================================================================
-- Drop triggers first
DROP TRIGGER IF EXISTS category_set_updated_at ON spendsense.category;
DROP TRIGGER IF EXISTS subcategory_set_updated_at ON spendsense.subcategory;

-- Drop tables
DROP TABLE IF EXISTS spendsense.subcategory CASCADE;
DROP TABLE IF EXISTS spendsense.category CASCADE;

-- Drop helper function
DROP FUNCTION IF EXISTS spendsense.map_budget_bucket_to_txn_type(TEXT);

COMMIT;

-- ============================================================================
-- Migration complete
-- ============================================================================
-- All category/subcategory data has been migrated to dim_category/dim_subcategory
-- Duplicate tables have been removed
-- View updated to use the standard schema
-- ============================================================================

-- ============================================================================
-- Fix Merchant Rules Taxonomy Alignment
-- Updates merchant_rules to use subcategory codes that exist in dim_subcategory
-- Also migrates existing enriched data to use correct codes
-- 
-- This migration aligns merchant rules with the actual taxonomy in dim_subcategory
-- ============================================================================

BEGIN;

-- ============================================================================
-- PART 1: Fix Dining / Food Rules
-- ============================================================================

-- Food delivery: dining/online_delivery -> food_dining/fd_online
UPDATE spendsense.merchant_rules
SET category_code = 'food_dining',
    subcategory_code = 'fd_online'
WHERE category_code = 'dining'
  AND subcategory_code = 'online_delivery'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_online' AND category_code = 'food_dining');

-- Bars/Pubs: dining/pubs_bars -> food_dining/fd_pubs_bars
UPDATE spendsense.merchant_rules
SET category_code = 'food_dining',
    subcategory_code = 'fd_pubs_bars'
WHERE category_code = 'dining'
  AND subcategory_code = 'pubs_bars'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_pubs_bars' AND category_code = 'food_dining');

-- Street food: dining/street_food -> food_dining/fd_street_food
UPDATE spendsense.merchant_rules
SET category_code = 'food_dining',
    subcategory_code = 'fd_street_food'
WHERE category_code = 'dining'
  AND subcategory_code = 'street_food'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_street_food' AND category_code = 'food_dining');

-- Generic restaurants: keep dining/casual_dining (if it exists) or set to food_dining/fd_fine_dining
UPDATE spendsense.merchant_rules
SET category_code = 'food_dining',
    subcategory_code = COALESCE(
        (SELECT subcategory_code FROM spendsense.dim_subcategory 
         WHERE category_code = 'food_dining' AND subcategory_code = 'fd_fine_dining' LIMIT 1),
        NULL
    )
WHERE category_code = 'dining'
  AND subcategory_code = 'casual_dining'
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'casual_dining' AND category_code = 'dining');

-- Cafes: dining/cafes_bistros -> food_dining/fd_cafes_bistros (or keep if exists)
UPDATE spendsense.merchant_rules
SET category_code = 'food_dining',
    subcategory_code = COALESCE(
        (SELECT subcategory_code FROM spendsense.dim_subcategory 
         WHERE category_code = 'food_dining' AND subcategory_code IN ('fd_cafes_bistros', 'cafes_bistros') LIMIT 1),
        subcategory_code
    )
WHERE category_code = 'dining'
  AND subcategory_code = 'cafes_bistros'
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'cafes_bistros' AND category_code = 'dining');

-- ============================================================================
-- PART 2: Fix Groceries Rules
-- ============================================================================

-- DMART / big chains: groceries/supermarkets -> groceries/groc_hyper
UPDATE spendsense.merchant_rules
SET subcategory_code = 'groc_hyper'
WHERE category_code = 'groceries'
  AND subcategory_code = 'supermarkets'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'groc_hyper' AND category_code = 'groceries');

-- Quick commerce: groceries/online_groceries -> groceries/groc_online
UPDATE spendsense.merchant_rules
SET subcategory_code = 'groc_online'
WHERE category_code = 'groceries'
  AND subcategory_code = 'online_groceries'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'groc_online' AND category_code = 'groceries');

-- Kirana stores: groceries/mom_and_pop -> groceries/groc_fv
UPDATE spendsense.merchant_rules
SET subcategory_code = 'groc_fv'
WHERE category_code = 'groceries'
  AND subcategory_code = 'mom_and_pop'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'groc_fv' AND category_code = 'groceries');

-- ============================================================================
-- PART 3: Fix Shopping / Ecommerce
-- ============================================================================

-- Online shopping: shopping/online_shopping -> shopping/amazon (or keep online_shopping if exists)
UPDATE spendsense.merchant_rules
SET subcategory_code = COALESCE(
        (SELECT subcategory_code FROM spendsense.dim_subcategory 
         WHERE category_code = 'shopping' AND subcategory_code = 'amazon' LIMIT 1),
        (SELECT subcategory_code FROM spendsense.dim_subcategory 
         WHERE category_code = 'shopping' AND subcategory_code = 'online_shopping' LIMIT 1),
        NULL
    )
WHERE category_code = 'shopping'
  AND subcategory_code = 'online_shopping'
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'online_shopping' AND category_code = 'shopping');

-- ============================================================================
-- PART 4: Fix Income Rules
-- ============================================================================

-- Salary: income/wages -> income/inc_salary
UPDATE spendsense.merchant_rules
SET subcategory_code = 'inc_salary'
WHERE category_code = 'income'
  AND subcategory_code = 'wages'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'inc_salary' AND category_code = 'income');

-- Refund/cashback: income/other_income -> income/inc_other
UPDATE spendsense.merchant_rules
SET subcategory_code = 'inc_other'
WHERE category_code = 'income'
  AND subcategory_code = 'other_income'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'inc_other' AND category_code = 'income');

-- ============================================================================
-- PART 5: Fix Loan / Fees Rules (Set to NULL if subcategory doesn't exist)
-- ============================================================================

-- Personal loan payment: remove non-existent subcategory
UPDATE spendsense.merchant_rules
SET subcategory_code = NULL
WHERE category_code = 'loan_payments'
  AND subcategory_code = 'personal_loan_payment'
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'personal_loan_payment' AND category_code = 'loan_payments');

-- Bank fees rule: remove non-existent other_bank_fees
UPDATE spendsense.merchant_rules
SET subcategory_code = NULL
WHERE category_code = 'bank_fees'
  AND subcategory_code = 'other_bank_fees'
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'other_bank_fees' AND category_code = 'bank_fees');

-- Tax payment: keep category only
UPDATE spendsense.merchant_rules
SET subcategory_code = NULL
WHERE category_code = 'government_and_non_profit'
  AND subcategory_code = 'tax_payment'
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'tax_payment' AND category_code = 'government_and_non_profit');

-- ============================================================================
-- PART 6: Fix Utilities / Medical (Set to NULL if subcategory doesn't exist)
-- ============================================================================

-- Utilities (mobile/internet): keep only category
UPDATE spendsense.merchant_rules
SET subcategory_code = NULL
WHERE category_code = 'utilities'
  AND subcategory_code IN ('mobile_telephone', 'internet_and_cable')
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = merchant_rules.subcategory_code AND category_code = 'utilities');

-- Medical: keep only category
UPDATE spendsense.merchant_rules
SET subcategory_code = NULL
WHERE category_code = 'medical'
  AND subcategory_code IN ('primary_care', 'pharmacies_and_supplements', 'other_medical')
  AND NOT EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = merchant_rules.subcategory_code AND category_code = 'medical');

-- ============================================================================
-- PART 7: Deactivate Rules with Invalid Codes (Final cleanup)
-- ============================================================================

-- Deactivate rules where subcategory_code still doesn't exist
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: subcategory_code does not exist in dim_subcategory'
WHERE subcategory_code IS NOT NULL
  AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory);

-- Deactivate rules where category_code doesn't exist
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: category_code does not exist in dim_category'
WHERE category_code IS NOT NULL
  AND category_code NOT IN (SELECT category_code FROM spendsense.dim_category);

-- ============================================================================
-- PART 8: Migrate Existing Enriched Data (Legacy Codes)
-- ============================================================================

-- Zomato-style online food -> food_dining/fd_online
UPDATE spendsense.txn_enriched
SET category_code = 'food_dining',
    subcategory_code = 'fd_online'
WHERE category_code = 'dining'
  AND subcategory_code = 'zomato'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_online' AND category_code = 'food_dining');

-- Bars/pubs -> food_dining/fd_pubs_bars
UPDATE spendsense.txn_enriched
SET category_code = 'food_dining',
    subcategory_code = 'fd_pubs_bars'
WHERE category_code = 'dining'
  AND subcategory_code = 'pubs_bars'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_pubs_bars' AND category_code = 'food_dining');

-- Income other_income -> income/inc_other
UPDATE spendsense.txn_enriched
SET subcategory_code = 'inc_other'
WHERE category_code = 'income'
  AND subcategory_code = 'other_income'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'inc_other' AND category_code = 'income');

-- ============================================================================
-- PART 9: Clean up enriched rows with invalid subcategory codes
-- ============================================================================

-- Set subcategory_code to NULL where it doesn't exist in dim_subcategory
UPDATE spendsense.txn_enriched
SET subcategory_code = NULL
WHERE subcategory_code IS NOT NULL
  AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory);

-- ============================================================================
-- PART 10: Clean up enriched rows with invalid category codes
-- ============================================================================

-- Set category_code to 'shopping' (fallback) where it doesn't exist
UPDATE spendsense.txn_enriched
SET category_code = 'shopping',
    subcategory_code = NULL
WHERE category_code IS NOT NULL
  AND category_code NOT IN (SELECT category_code FROM spendsense.dim_category);

COMMIT;
-- ============================================================================
-- Fix Taxonomy Mappings and Add Description-Based Rules
-- 
-- This migration:
-- 1. Fixes remaining taxonomy mismatches (online_groceries → groc_online, etc.)
-- 2. Adds description-based rules for coffee/tea, vegetables, fuel
-- 3. Updates cafe rules to use food_dining/fd_cafes
-- ============================================================================

BEGIN;

-- ============================================================================
-- PART 1: Fix Remaining Taxonomy Mappings
-- ============================================================================

-- Quick commerce: groceries/online_groceries → groceries/groc_online
UPDATE spendsense.merchant_rules
SET subcategory_code = 'groc_online'
WHERE category_code = 'groceries'
  AND subcategory_code = 'online_groceries'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'groc_online' AND category_code = 'groceries');

-- Migrate existing enriched data: online_groceries → groc_online
UPDATE spendsense.txn_enriched
SET subcategory_code = 'groc_online'
WHERE category_code = 'groceries'
  AND subcategory_code = 'online_groceries'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'groc_online' AND category_code = 'groceries');

-- Cafes: dining/cafes_bistros → food_dining/fd_cafes
UPDATE spendsense.merchant_rules
SET category_code = 'food_dining',
    subcategory_code = 'fd_cafes'
WHERE category_code = 'dining'
  AND subcategory_code = 'cafes_bistros'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_cafes' AND category_code = 'food_dining');

-- Migrate existing enriched data: cafes_bistros → fd_cafes
UPDATE spendsense.txn_enriched
SET category_code = 'food_dining',
    subcategory_code = 'fd_cafes'
WHERE category_code = 'dining'
  AND subcategory_code = 'cafes_bistros'
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'fd_cafes' AND category_code = 'food_dining');

-- ============================================================================
-- PART 2: Add Description-Based Rules for Common Patterns
-- ============================================================================

-- Coffee/Tea in description → food_dining/fd_cafes
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 40, 'description',
 '(?i)\b(COFFEE|CAPPUCCINO|LATTE|ESPRESSO|CAF[EÉ]|TEA|CHAI|MASALA\s*CHAI|GREEN\s*TEA|BLACK\s*TEA)\b',
 'food_dining', 'fd_cafes', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Vegetables/Fruits in description → groceries/groc_fv
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 45, 'description',
 '(?i)\b(POTATO(?:ES)?|CARROT(?:S)?|TOMATO(?:ES)?|ONION(?:S)?|VEGETABLES?|FRUIT(?:S)?|GREEN(?:S)?|SABZI|SABJI|BHINDI|BRINJAL|CABBAGE|CAULIFLOWER|BEANS|PEAS|CORN|APPLE|BANANA|ORANGE|MANGO|GRAPES)\b',
 'groceries', 'groc_fv', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Fuel keywords in description → motor_maintenance/automotive_services
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 30, 'description',
 '(?i)\b(FUEL|PETROL|DIESEL|DISEL|GASOLINE|GAS\s*FILL|REFUEL)\b',
 'motor_maintenance', 'automotive_services', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- BP (British Petroleum) as merchant → motor_maintenance/automotive_services
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 26, 'merchant',
 '(?i)^BP$|^(BP\s*CL|BPCL)$',
 'motor_maintenance', 'automotive_services', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Rent/Housing payments in description → housing_fixed/house_rent
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 25, 'description',
 '(?i)\b(RENT|HOUSE\s*RENT|MONTHLY\s*RENT|ROOM\s*RENT|APARTMENT\s*RENT)\b',
 'housing_fixed', 'house_rent', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Maid/House help in description → housing_fixed/house_maid
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 28, 'description',
 '(?i)\b(MAID|HOUSE\s*HELP|HOUSE\s*KEEPER|COOK|CLEANER|DOMESTIC\s*HELP|MONTHLY\s*PAYMENT.*MAID)\b',
 'housing_fixed', 'house_maid', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- PART 3: Clean up any remaining invalid codes
-- ============================================================================

-- Set subcategory to NULL where it doesn't exist
UPDATE spendsense.merchant_rules
SET subcategory_code = NULL,
    notes = COALESCE(notes || '; ', '') || 'Subcategory code does not exist, set to NULL'
WHERE subcategory_code IS NOT NULL
  AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory);

-- Deactivate rules with invalid category codes
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: category_code does not exist'
WHERE category_code IS NOT NULL
  AND category_code NOT IN (SELECT category_code FROM spendsense.dim_category);

-- Clean up enriched data with invalid subcategory codes
UPDATE spendsense.txn_enriched
SET subcategory_code = NULL
WHERE subcategory_code IS NOT NULL
  AND subcategory_code NOT IN (SELECT subcategory_code FROM spendsense.dim_subcategory);

COMMIT;

-- ============================================================================
-- Seed: Key India Merchants + Merchant Rules (Tier 1)
-- Aligned to dim_category / dim_subcategory taxonomy
-- ============================================================================

BEGIN;

-- ============================================================================
-- PART 1: Merchants (dim_merchant table)
-- ============================================================================

INSERT INTO spendsense.dim_merchant (merchant_id, merchant_name, normalized_name, website, active) VALUES
  -- Food delivery / eating out
  (gen_random_uuid(), 'Swiggy',           'swiggy',           'https://www.swiggy.com',           true),
  (gen_random_uuid(), 'Zomato',           'zomato',           'https://www.zomato.com',           true),
  (gen_random_uuid(), 'EatSure',          'eatsure',          'https://www.eatsure.com',          true),
  (gen_random_uuid(), 'Dominos',          'dominos',          'https://www.dominos.co.in',        true),
  (gen_random_uuid(), 'McDonalds',        'mcdonalds',        'https://www.mcdonaldsindia.com',   true),
  (gen_random_uuid(), 'KFC',              'kfc',              'https://online.kfc.co.in',         true),
  (gen_random_uuid(), 'Burger King',      'burgerking',       'https://www.burgerking.in',        true),
  (gen_random_uuid(), 'Pizza Hut',        'pizzahut',         'https://www.pizzahut.co.in',       true),
  (gen_random_uuid(), 'Barbeque Nation',  'barbequenation',   'https://www.barbequenation.com',   true),
  (gen_random_uuid(), 'CCD',              'ccd',              'https://www.cafecoffeeday.com',    true),
  (gen_random_uuid(), 'Starbucks',        'starbucks',        'https://www.starbucks.in',         true),
  (gen_random_uuid(), 'Wow! Momo',        'wowmomo',          'https://www.wowmomo.com',          true),
  (gen_random_uuid(), 'Faasos',           'faasos',           'https://www.faasos.com',           true),
  (gen_random_uuid(), 'Behrouz Biryani',  'behrouz',          'https://www.behrouzbiryani.com',   true),
  (gen_random_uuid(), 'Mojo Pizza',       'mojopizza',        'https://www.mojopizza.in',         true),
  (gen_random_uuid(), 'Biryani Blues',    'biryaniblues',     'https://www.biryaniblues.com',     true),
  (gen_random_uuid(), 'Paradise Biryani', 'paradise',         'https://paradisefoodcourt.in',     true),

  -- Groceries / Q-commerce
  (gen_random_uuid(), 'DMart',            'dmart',            'https://www.dmart.in',             true),
  (gen_random_uuid(), 'BigBasket',        'bigbasket',        'https://www.bigbasket.com',        true),
  (gen_random_uuid(), 'Zepto',            'zepto',            'https://www.zeptonow.com',         true),
  (gen_random_uuid(), 'Blinkit',          'blinkit',          'https://blinkit.com',              true),
  (gen_random_uuid(), 'Reliance Smart',   'reliancesmart',    'https://www.relianceretail.com',   true),
  (gen_random_uuid(), 'More Supermarket', 'more',             'https://www.moreretail.in',        true),
  (gen_random_uuid(), 'Spencer''s',       'spencers',         'https://www.spencers.in',          true),
  (gen_random_uuid(), 'Spar',             'spar',             'https://www.sparindia.com',        true),
  (gen_random_uuid(), 'Nature''s Basket', 'naturesbasket',    'https://www.naturesbasket.co.in',  true),
  (gen_random_uuid(), 'Lulu Hypermarket', 'lulu',             'https://www.luluhypermarket.in',   true),
  (gen_random_uuid(), 'Ratnadeep',        'ratnadeep',        NULL,                               true),

  -- Online shopping / retail
  (gen_random_uuid(), 'Amazon',           'amazon',           'https://www.amazon.in',            true),
  (gen_random_uuid(), 'Flipkart',         'flipkart',         'https://www.flipkart.com',         true),
  (gen_random_uuid(), 'Ajio',             'ajio',             'https://www.ajio.com',             true),
  (gen_random_uuid(), 'Myntra',           'myntra',           'https://www.myntra.com',           true),
  (gen_random_uuid(), 'Nykaa',            'nykaa',            'https://www.nykaa.com',            true),
  (gen_random_uuid(), 'Meesho',           'meesho',           'https://www.meesho.com',           true),
  (gen_random_uuid(), 'Tata Cliq',        'tatacliq',         'https://www.tatacliq.com',         true),
  (gen_random_uuid(), 'Reliance Digital', 'reliancedigital',  'https://www.reliancedigital.in',   true),
  (gen_random_uuid(), 'Croma',            'croma',            'https://www.croma.com',            true),
  (gen_random_uuid(), 'Vijay Sales',      'vijaysales',       'https://www.vijaysales.com',       true),
  (gen_random_uuid(), 'Lifestyle',        'lifestyle',        'https://www.lifestylestores.com',  true),
  (gen_random_uuid(), 'Max Fashion',      'max',              'https://www.maxfashion.in',        true),
  (gen_random_uuid(), 'Pantaloons',       'pantaloons',       'https://www.pantaloons.com',       true),
  (gen_random_uuid(), 'Decathlon',        'decathlon',        'https://www.decathlon.in',         true),
  (gen_random_uuid(), 'Shoppers Stop',    'shoppersstop',     'https://www.shoppersstop.com',     true),

  -- Transport / mobility
  (gen_random_uuid(), 'Ola',              'ola',              'https://www.olacabs.com',          true),
  (gen_random_uuid(), 'Uber',             'uber',             'https://www.uber.com',             true),
  (gen_random_uuid(), 'Rapido',           'rapido',           'https://rapido.bike',              true),
  (gen_random_uuid(), 'Redbus',           'redbus',           'https://www.redbus.in',            true),
  (gen_random_uuid(), 'IRCTC',            'irctc',            'https://www.irctc.co.in',          true),
  (gen_random_uuid(), 'IndiGo',           'indigo',           'https://www.goindigo.in',          true),
  (gen_random_uuid(), 'Air India',        'airindia',         'https://www.airindia.com',         true),
  (gen_random_uuid(), 'Vistara',          'vistara',          'https://www.airvistara.com',       true),
  (gen_random_uuid(), 'Akasa Air',        'akasa',            'https://www.akasaair.com',         true),

  -- Fuel
  (gen_random_uuid(), 'HPCL',             'hpcl',             'https://www.hindustanpetroleum.com', true),
  (gen_random_uuid(), 'BPCL',             'bpcl',             'https://www.bharatpetroleum.com',    true),
  (gen_random_uuid(), 'IOCL',             'iocl',             'https://www.iocl.com',               true),
  (gen_random_uuid(), 'Indian Oil',       'indianoil',        'https://www.iocl.com',               true),
  (gen_random_uuid(), 'Shell',            'shell',            'https://www.shell.in',               true),
  (gen_random_uuid(), 'Reliance Petro',   'reliancepetro',    NULL,                                 true),
  (gen_random_uuid(), 'Jio-bp',           'jiobp',            NULL,                                 true),

  -- Telecom / Internet / DTH
  (gen_random_uuid(), 'Airtel',           'airtel',           'https://www.airtel.in',           true),
  (gen_random_uuid(), 'Jio',              'jio',              'https://www.jio.com',              true),
  (gen_random_uuid(), 'VI',               'vi',               'https://www.myvi.in',              true),
  (gen_random_uuid(), 'Vodafone Idea',    'vodafoneidea',     'https://www.myvi.in',              true),
  (gen_random_uuid(), 'BSNL',             'bsnl',             'https://www.bsnl.co.in',           true),
  (gen_random_uuid(), 'ACT Fibernet',     'actfibernet',      'https://www.actcorp.in',           true),
  (gen_random_uuid(), 'Hathway',          'hathway',          'https://www.hathway.com',          true),
  (gen_random_uuid(), 'Tikona',           'tikona',           'https://www.tikonadigital.com',    true),
  (gen_random_uuid(), 'JioFiber',         'jiofiber',         'https://www.jio.com/fiber',        true),
  (gen_random_uuid(), 'Airtel Xstream',   'airtelxstream',    'https://www.airtel.in/broadband',  true),
  (gen_random_uuid(), 'Tata Play',        'tataplay',         'https://www.tataplay.com',         true),
  (gen_random_uuid(), 'Sun Direct',       'sundirect',        'https://www.sundirect.in',          true),
  (gen_random_uuid(), 'Dish TV',          'dishtv',           'https://www.dishtv.in',            true),

  -- Wallets / UPI
  (gen_random_uuid(), 'Paytm',            'paytm',            'https://paytm.com',                true),
  (gen_random_uuid(), 'PhonePe',          'phonepe',          'https://www.phonepe.com',          true),
  (gen_random_uuid(), 'Google Pay',       'googlepay',        'https://pay.google.com',           true),
  (gen_random_uuid(), 'Amazon Pay',       'amazonpay',        'https://www.amazon.in',            true),

  -- Entertainment / OTT
  (gen_random_uuid(), 'Netflix',          'netflix',          'https://www.netflix.com',          true),
  (gen_random_uuid(), 'Amazon Prime',     'amazonprime',      'https://www.primevideo.com',       true),
  (gen_random_uuid(), 'Disney+ Hotstar',  'hotstar',          'https://www.hotstar.com',          true),
  (gen_random_uuid(), 'Spotify',          'spotify',          'https://www.spotify.com',          true),
  (gen_random_uuid(), 'BookMyShow',       'bookmyshow',       'https://in.bookmyshow.com',        true),
  (gen_random_uuid(), 'PVR',              'pvr',              'https://www.pvrcinemas.com',       true),
  (gen_random_uuid(), 'INOX',             'inox',             'https://www.inoxmovies.com',       true),
  (gen_random_uuid(), 'Zee5',             'zee5',             'https://www.zee5.com',             true),
  (gen_random_uuid(), 'Sony LIV',         'sonyliv',          'https://www.sonyliv.com',          true),

  -- Healthcare / pharmacies
  (gen_random_uuid(), 'Apollo Pharmacy',  'apollopharmacy',   'https://www.apollopharmacy.in',    true),
  (gen_random_uuid(), '1mg',              '1mg',              'https://www.1mg.com',              true),
  (gen_random_uuid(), 'PharmEasy',        'pharmeasy',        'https://www.pharmeasy.in',         true),
  (gen_random_uuid(), 'Netmeds',          'netmeds',          'https://www.netmeds.com',          true),
  (gen_random_uuid(), 'MedPlus',          'medplus',          'https://www.medplusmart.com',      true),
  (gen_random_uuid(), 'Dr Lal PathLabs',  'drlalpath',        'https://www.lalpathlabs.com',      true),
  (gen_random_uuid(), 'Thyrocare',        'thyrocare',        'https://www.thyrocare.com',        true),
  (gen_random_uuid(), 'Apollo Hospitals', 'apollohospitals',  'https://www.apollohospitals.com',  true),
  (gen_random_uuid(), 'Fortis',           'fortis',           'https://www.fortishealthcare.com', true),
  (gen_random_uuid(), 'Manipal Hospitals','manipal',          'https://www.manipalhospitals.com', true),

  -- Personal care / services
  (gen_random_uuid(), 'Urban Company',    'urbancompany',     'https://www.urbancompany.com',     true),
  (gen_random_uuid(), 'Lakme Salon',      'lakmesalon',       'https://www.lakmeindia.com',       true),
  (gen_random_uuid(), 'Naturals Salon',   'naturals',         'https://naturals.in',              true),
  (gen_random_uuid(), 'Enrich Salon',     'enrichsalon',      'https://www.enrichsalon.com',      true),
  (gen_random_uuid(), 'Purplle',          'purplle',          'https://www.purplle.com',          true),
  (gen_random_uuid(), 'Sugar Cosmetics',  'sugarcosmetics',   'https://in.sugarcosmetics.com',    true),
  (gen_random_uuid(), 'Beardo',           'beardo',           'https://beardo.in',                true)
ON CONFLICT (normalized_name) DO NOTHING;

-- ============================================================================
-- PART 2: Merchant Rules (aligned to correct taxonomy)
-- ============================================================================
-- Note: priorities: 10–30 = strong brand match, 40+ = generic patterns

-- ---------- Food Delivery & Dining (food_dining) ----------

INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
  -- Online food delivery
  (gen_random_uuid(), 18, 'merchant', '(?i)\b(SWIGGY|ZOMATO|EATSURE)\b',
   'food_dining', 'fd_online', true, 'seed', NULL, NULL),

  -- Quick service / fast food chains
  (gen_random_uuid(), 20, 'merchant', '(?i)\b(DOMINOS|MCDONALD''?S?|KFC|BURGER\s*KING|PIZZA\s*HUT|WOW\s*MOMO|FAASOS|MOJO\s*PIZZA)\b',
   'food_dining', 'fd_quick_service', true, 'seed', NULL, NULL),

  -- Biryani / casual dining brands
  (gen_random_uuid(), 25, 'merchant', '(?i)\b(BIRYANI\s*BLUES|PARADISE|BEHROOZ|BARBEQUE\s*NATION)\b',
   'food_dining', 'fd_fine', true, 'seed', NULL, NULL),

  -- Cafes & coffee
  (gen_random_uuid(), 22, 'merchant', '(?i)\b(STARBUCKS|CAF[EÉ]\s*COFFEE\s*DAY|CCD)\b',
   'food_dining', 'fd_cafes', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- Groceries (groceries) ----------

INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
  -- Hypermarkets / big chains
  (gen_random_uuid(), 20, 'merchant', '(?i)\b(DMART|SPAR|SPENCERS|LULU|RELIANCE\s*SMART|MORE\s*SUPERMARKET|NATURE''?S\s*BASKET|RATNADEEP)\b',
   'groceries', 'groc_hyper', true, 'seed', NULL, NULL),

  -- Online groceries / Q-commerce
  (gen_random_uuid(), 18, 'merchant', '(?i)\b(BIGBASKET|ZEPTO|BLINKIT)\b',
   'groceries', 'groc_online', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- Shopping & Retail (shopping) ----------

INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
  -- Online shopping (Amazon / Flipkart / etc.) → "amazon" bucket
  (gen_random_uuid(), 18, 'merchant', '(?i)\b(AMAZON|FLIPKART|AJIO|MYNTRA|NYKAA|MEESHO|TATA\s*CLIQ)\b',
   'shopping', 'amazon', true, 'seed', NULL, NULL),

  -- Electronics chains
  (gen_random_uuid(), 22, 'merchant', '(?i)\b(CROMA|RELIANCE\s*DIGITAL|VIJAY\s*SALES)\b',
   'shopping', 'electronics', true, 'seed', NULL, NULL),

  -- Fashion retail
  (gen_random_uuid(), 25, 'merchant', '(?i)\b(LIFESTYLE|MAX\s*FASHION|PANTALOONS|SHOPPERS\s*STOP|ZARA|H&M)\b',
   'shopping', 'clothing_and_accessories', true, 'seed', NULL, NULL),

  -- Sports & gear
  (gen_random_uuid(), 28, 'merchant', '(?i)\b(DECATHLON)\b',
   'shopping', 'department_stores', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- Transport & Mobility (transportation / travel) ----------

INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
  -- Ride apps (Uber / Ola / Rapido)
  (gen_random_uuid(), 18, 'merchant', '(?i)\b(OLA|UBER|RAPIDO)\b',
   'transportation', 'digital_apps', true, 'seed', NULL, NULL),

  -- Buses / trains
  (gen_random_uuid(), 25, 'merchant', '(?i)\b(REDBUS|IRCTC)\b',
   'transportation', 'public_transit', true, 'seed', NULL, NULL),

  -- Airlines (travel / flights)
  (gen_random_uuid(), 22, 'merchant', '(?i)\b(INDIGO|AIR\s*INDIA|VISTARA|AKASA)\b',
   'travel', 'flight', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- Fuel / Motor Maintenance (motor_maintenance) ----------

INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
  -- Petrol pumps (brand-based)
  (gen_random_uuid(), 20, 'merchant', '(?i)\b(HPCL|BPCL|IOCL|INDIAN\s*OIL|SHELL|JIO[-\s]*BP|RELIANCE\s*PETRO)\b',
   'motor_maintenance', 'automotive_services', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- Utilities (utilities) ----------

INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
  -- Mobile bills
  (gen_random_uuid(), 22, 'merchant', '(?i)\b(AIRTEL|JIO|VODAFONE|VI\b|BSNL)\b',
   'utilities', 'mobile_telephone', true, 'seed', NULL, NULL),

  -- Broadband / internet
  (gen_random_uuid(), 23, 'merchant', '(?i)\b(JIOFIBER|AIRTEL\s*(XSTREAM|FIBER)|ACT\s*FIBERNET|HATHWAY|TIKONA)\b',
   'utilities', 'internet_and_cable', true, 'seed', NULL, NULL),

  -- DTH / TV
  (gen_random_uuid(), 30, 'merchant', '(?i)\b(TATA\s*PLAY|SUN\s*DIRECT|DISH\s*TV)\b',
   'utilities', 'internet_and_cable', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- Wallets / UPI (leave category NULL, let fallback handle) ----------

INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
  (gen_random_uuid(), 40, 'merchant', '(?i)\b(PAYTM|PHONEPE|GOOGLE\s*PAY|GPAY|AMAZON\s*PAY)\b',
   NULL, NULL, true, 'seed', NULL, NULL)  -- let fallback logic handle txn_type/category
ON CONFLICT DO NOTHING;

-- ---------- Healthcare (medical) ----------

INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
  -- Pharmacies
  (gen_random_uuid(), 25, 'merchant', '(?i)\b(APOLLO\s*PHARMACY|MEDPLUS|PHARM(EASY)?|NETMEDS|1MG)\b',
   'medical', 'pharmacies_and_supplements', true, 'seed', NULL, NULL),

  -- Labs / diagnostics
  (gen_random_uuid(), 28, 'merchant', '(?i)\b(DR\.?\s*LAL|LAL\s*PATHLABS|THYROCARE)\b',
   'medical', 'other_medical', true, 'seed', NULL, NULL),

  -- Hospitals / primary care
  (gen_random_uuid(), 30, 'merchant', '(?i)\b(APOLLO\s*HOSPITALS?|FORTIS|MANIPAL)\b',
   'medical', 'primary_care', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- Entertainment & OTT (entertainment) ----------

INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
  -- OTT subscriptions
  (gen_random_uuid(), 22, 'merchant', '(?i)\b(NETFLIX|AMAZON\s*PRIME|PRIME\s*VIDEO|DISNEY\+?\s*HOTSTAR|ZEE5|SONY\s*LIV)\b',
   'entertainment', 'ent_movies_ott', true, 'seed', NULL, NULL),

  -- Cinemas
  (gen_random_uuid(), 25, 'merchant', '(?i)\b(PVR|INOX)\b',
   'entertainment', 'ent_movies_ott', true, 'seed', NULL, NULL),

  -- Ticketing
  (gen_random_uuid(), 26, 'merchant', '(?i)\b(BOOKMYSHOW)\b',
   'entertainment', 'ent_sports_events', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- Personal Care & Services (personal_care / general_services) ----------

INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
  -- Salons & grooming
  (gen_random_uuid(), 30, 'merchant', '(?i)\b(LAKME\s*SALON|NATURALS|ENRICH\s*SALON)\b',
   'personal_care', 'hair_and_skin_services', true, 'seed', NULL, NULL),

  -- Home services (Urban Company)
  (gen_random_uuid(), 28, 'merchant', '(?i)\b(URBAN\s*COMPANY)\b',
   'general_services', 'other_general_services', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- ---------- Income (income) ----------

INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
  -- Salary credits
  (gen_random_uuid(), 18, 'description', '(?i)\b(SALARY\s*(CREDIT|PAY)|PAYROLL|NEFT\s*CREDIT.*SALARY)\b',
   'income', 'inc_salary', true, 'seed', NULL, NULL),

  -- Refunds / cashback
  (gen_random_uuid(), 30, 'description', '(?i)\b(REFUND|CASHBACK|REVERSAL)\b',
   'income', 'inc_other', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

COMMIT;

-- ============================================================================
-- Deactivate Old Taxonomy Rules
-- Deactivate rules using old taxonomy codes (dining/zomato, etc.)
-- These are replaced by new rules with correct taxonomy (food_dining/fd_online, etc.)
-- ============================================================================

BEGIN;

-- Deactivate old dining/zomato rules (replaced by food_dining/fd_online)
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: replaced by food_dining/fd_online rules'
WHERE category_code = 'dining'
  AND subcategory_code = 'zomato'
  AND active = true;

-- Deactivate old dining/online_delivery rules if they exist (replaced by food_dining/fd_online)
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: replaced by food_dining/fd_online rules'
WHERE category_code = 'dining'
  AND subcategory_code = 'online_delivery'
  AND active = true;

-- Deactivate old dining/cafes_bistros rules (replaced by food_dining/fd_cafes)
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: replaced by food_dining/fd_cafes rules'
WHERE category_code = 'dining'
  AND subcategory_code = 'cafes_bistros'
  AND active = true;

-- Deactivate old groceries/online_groceries rules (replaced by groceries/groc_online)
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: replaced by groceries/groc_online rules'
WHERE category_code = 'groceries'
  AND subcategory_code = 'online_groceries'
  AND active = true;

-- Deactivate old groceries/supermarkets rules (replaced by groceries/groc_hyper)
UPDATE spendsense.merchant_rules
SET active = false,
    notes = COALESCE(notes || '; ', '') || 'Deactivated: replaced by groceries/groc_hyper rules'
WHERE category_code = 'groceries'
  AND subcategory_code = 'supermarkets'
  AND active = true;

COMMIT;

-- ============================================================================
-- Add More Description-Based Rules for Common Patterns
-- These will catch transactions that don't match merchant-based rules
-- ============================================================================

BEGIN;

-- Hotels/Restaurants in description → food_dining/fd_fine
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 35, 'description', '\y(HOTEL|RESTAURANT|DINING|BIRYANI|TANDOORI|MESS)\y',
 'food_dining', 'fd_fine', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Pet clinic/vet in description → pets/pet_vaccine
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 30, 'description', '\y(PET\s*CLINIC|VET|VETERINARY|ANIMAL\s*HOSPITAL)\y',
 'pets', 'pet_vaccine', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Chicken/meat in description → groceries/groc_fv
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 40, 'description', '\y(CHICKEN|MEAT|MUTTON|FISH|EGG|EGGS)\y',
 'groceries', 'groc_fv', true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- Finance/loan/emi in description → loan_payments (generic)
INSERT INTO spendsense.merchant_rules
(rule_id, priority, applies_to, pattern_regex, category_code, subcategory_code, active, source, tenant_id, created_by)
VALUES
(gen_random_uuid(), 25, 'description', '\y(FINANCE|LOAN|EMI|INSTALLMENT)\y',
 'loan_payments', NULL, true, 'seed', NULL, NULL)
ON CONFLICT DO NOTHING;

-- American Express (credit card) → could be shopping or transfer
-- Leave as default for now, user can categorize manually

COMMIT;

-- ============================================================================
-- Add Default Subcategories for Transactions Without Matches
-- Updates enrichment logic to assign default subcategories when rules match
-- but don't provide a subcategory, or when falling back to default category
-- ============================================================================

BEGIN;

-- Update loan_payments rules that don't have subcategory to use a default
-- First, check what loan_payment subcategories exist
-- Then update rules to use the first available one, or set a sensible default

-- For loan_payments, if no subcategory is specified, use credit_card_payment as default
-- (most common loan payment type)
UPDATE spendsense.merchant_rules
SET subcategory_code = 'credit_card_payment'
WHERE category_code = 'loan_payments'
  AND subcategory_code IS NULL
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'credit_card_payment' AND category_code = 'loan_payments');

-- For shopping, if no subcategory is specified, use 'amazon' as default
-- (the generic "Online Shopping" bucket)
UPDATE spendsense.merchant_rules
SET subcategory_code = 'amazon'
WHERE category_code = 'shopping'
  AND subcategory_code IS NULL
  AND active = true
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'amazon' AND category_code = 'shopping');

-- Update the enrichment pipeline to assign default subcategories when category is set but subcategory is NULL
-- This is done in the pipeline.py code, but we can also update existing enriched records

-- For existing loan_payments without subcategory, assign credit_card_payment
UPDATE spendsense.txn_enriched
SET subcategory_code = 'credit_card_payment'
WHERE category_code = 'loan_payments'
  AND subcategory_code IS NULL
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'credit_card_payment' AND category_code = 'loan_payments');

-- For existing shopping without subcategory, assign 'amazon' (generic online shopping)
UPDATE spendsense.txn_enriched
SET subcategory_code = 'amazon'
WHERE category_code = 'shopping'
  AND subcategory_code IS NULL
  AND EXISTS (SELECT 1 FROM spendsense.dim_subcategory WHERE subcategory_code = 'amazon' AND category_code = 'shopping');

COMMIT;

