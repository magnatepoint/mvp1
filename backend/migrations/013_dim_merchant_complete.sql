-- ============================================================================
-- Migration 013: Enhanced dim_merchant Schema + Integration
-- Consolidates: 056_dim_merchant_complete.sql + 057_integrate_dim_merchant.sql
-- 
-- 1. Replaces basic dim_merchant with enhanced schema
-- 2. Creates merchant_alias table for flexible matching
-- 3. Populates 200+ India merchants with correct taxonomy
-- 4. Generates aliases from brand_keywords
-- 5. Integrates dim_merchant with fn_match_merchant function
-- ============================================================================

BEGIN;

SET search_path TO spendsense, public, extensions;

-- ============================================================================
-- Migration 056: Enhanced dim_merchant Schema + Full India Merchant Dataset
-- 
-- 1. Replaces basic dim_merchant with enhanced schema
-- 2. Creates merchant_alias table for flexible matching
-- 3. Populates 200+ India merchants with correct taxonomy
-- 4. Generates aliases from brand_keywords
-- ============================================================================

BEGIN;

SET search_path TO spendsense, public, extensions;

-- ============================================================================
-- 1) Create merchant_alias table first (no dependencies)
-- ============================================================================

-- Drop if exists to ensure clean schema
DROP TABLE IF EXISTS spendsense.merchant_alias CASCADE;

CREATE TABLE spendsense.merchant_alias (
    alias_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL,
    alias TEXT NOT NULL,
    normalized_alias TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (merchant_id, normalized_alias)
);

CREATE INDEX ix_alias_norm 
ON spendsense.merchant_alias(normalized_alias);

CREATE INDEX ix_alias_merchant_id 
ON spendsense.merchant_alias(merchant_id);

COMMENT ON TABLE spendsense.merchant_alias IS 'Aliases for merchants to handle messy UPI strings and variations';

-- ============================================================================
-- 2) Migrate existing dim_merchant data to temporary table
-- ============================================================================

CREATE TEMP TABLE dim_merchant_backup AS
SELECT * FROM spendsense.dim_merchant;

-- ============================================================================
-- 3) Drop and recreate dim_merchant with enhanced schema
-- ============================================================================

-- Drop foreign key constraints that reference dim_merchant
ALTER TABLE IF EXISTS spendsense.txn_fact 
    DROP CONSTRAINT IF EXISTS txn_fact_merchant_id_fkey;

ALTER TABLE IF EXISTS spendsense.txn_enriched 
    DROP CONSTRAINT IF EXISTS txn_enriched_merchant_id_fkey;

ALTER TABLE IF EXISTS spendsense.kpi_recurring_merchants_monthly 
    DROP CONSTRAINT IF EXISTS fk_kpi_rec_merchants_dim_merchant;

-- Drop old table
DROP TABLE IF EXISTS spendsense.dim_merchant CASCADE;

-- Create new enhanced dim_merchant table
CREATE TABLE spendsense.dim_merchant (
    merchant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_code TEXT UNIQUE NOT NULL,            -- short identifier: swiggy, amazon, ola
    merchant_name TEXT NOT NULL,                   -- Display name: Swiggy
    normalized_name TEXT NOT NULL,                 -- lowercase: swiggy
    brand_keywords TEXT[] NOT NULL DEFAULT '{}',   -- ["swiggy", "instamart", "swig"]
    category_code TEXT NOT NULL REFERENCES spendsense.dim_category(category_code),
    subcategory_code TEXT REFERENCES spendsense.dim_subcategory(subcategory_code),
    website TEXT,
    merchant_type TEXT,                            -- "online", "wallet", "utility", "ride", etc.
    country_code TEXT NOT NULL DEFAULT 'IN',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (normalized_name),
    UNIQUE (merchant_code)
);

-- Add GIN index for brand_keywords
CREATE INDEX IF NOT EXISTS ix_dim_merchant_keywords
ON spendsense.dim_merchant USING GIN (brand_keywords);

-- Add index for category lookups
CREATE INDEX IF NOT EXISTS ix_dim_merchant_category
ON spendsense.dim_merchant(category_code, subcategory_code)
WHERE active = TRUE;

-- Add index for normalized_name lookups
CREATE INDEX IF NOT EXISTS ix_dim_merchant_normalized
ON spendsense.dim_merchant(normalized_name)
WHERE active = TRUE;

COMMENT ON TABLE spendsense.dim_merchant IS 'Enhanced merchant dimension table with brand keywords and taxonomy mapping';
COMMENT ON COLUMN spendsense.dim_merchant.merchant_code IS 'Short unique identifier (e.g., swiggy, amazon)';
COMMENT ON COLUMN spendsense.dim_merchant.brand_keywords IS 'Array of brand keywords for fuzzy matching';
COMMENT ON COLUMN spendsense.dim_merchant.merchant_type IS 'Type: online, offline, wallet, utility, ride, etc.';

-- ============================================================================
-- 4) Restore existing merchants (if any) with new schema
-- ============================================================================

-- Only restore if backup table exists and has data
-- Note: Old schema only has merchant_name, normalized_name, website, active
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'dim_merchant_backup') THEN
        INSERT INTO spendsense.dim_merchant (
            merchant_code, merchant_name, normalized_name, brand_keywords,
            category_code, subcategory_code, merchant_type, website, active
        )
        SELECT 
            normalized_name AS merchant_code,
            merchant_name,
            normalized_name,
            ARRAY[normalized_name] AS brand_keywords,
            'shopping' AS category_code,  -- Default fallback
            NULL AS subcategory_code,     -- No default subcategory
            'online' AS merchant_type,
            website,
            active
        FROM dim_merchant_backup
        WHERE normalized_name IS NOT NULL
        ON CONFLICT (merchant_code) DO NOTHING;
    END IF;
END $$;

-- ============================================================================
-- 5) Insert Full India Merchant Dataset (200+ merchants)
-- ============================================================================
-- Mapped to correct taxonomy from migration 052

-- 🍔 FOOD & DINING (Delivery, Restaurants, Cafes)
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
-- Online Food Delivery
('swiggy', 'Swiggy', 'swiggy', ARRAY['swiggy','instamart','swig'], 'food_dining', 'fd_online', 'online', 'https://www.swiggy.com'),
('zomato', 'Zomato', 'zomato', ARRAY['zomato'], 'food_dining', 'fd_online', 'online', 'https://www.zomato.com'),
('eatsure', 'EatSure', 'eatsure', ARRAY['eatsure'], 'food_dining', 'fd_online', 'online', NULL),

-- Fast Food
('mcd', 'McDonalds', 'mcdonalds', ARRAY['mcdonalds','mcd'], 'food_dining', 'fd_quick_service', 'offline', 'https://www.mcdonalds.com'),
('kfc', 'KFC', 'kfc', ARRAY['kfc'], 'food_dining', 'fd_quick_service', 'offline', 'https://www.kfc.co.in'),
('burgerking', 'Burger King', 'burgerking', ARRAY['burgerking','burger king'], 'food_dining', 'fd_quick_service', 'offline', 'https://www.burgerking.in'),
('dominos', 'Domino''s Pizza', 'dominos', ARRAY['dominos','domino'], 'food_dining', 'fd_quick_service', 'offline', 'https://www.dominos.co.in'),
('pizzahut', 'Pizza Hut', 'pizzahut', ARRAY['pizza hut'], 'food_dining', 'fd_quick_service', 'offline', 'https://www.pizzahut.co.in'),
('wowmomo', 'Wow! Momo', 'wowmomo', ARRAY['wow momo','wow! momo'], 'food_dining', 'fd_quick_service', 'offline', NULL),

-- Cafes & Desserts
('starbucks', 'Starbucks', 'starbucks', ARRAY['starbucks'], 'food_dining', 'fd_cafes', 'offline', 'https://www.starbucks.in'),
('ccd', 'Cafe Coffee Day', 'ccd', ARRAY['ccd','cafe coffee day'], 'food_dining', 'fd_cafes', 'offline', 'https://www.cafecoffeeday.com'),
('theobroma', 'Theobroma', 'theobroma', ARRAY['theobroma'], 'food_dining', 'fd_desserts', 'offline', NULL),
('naturals', 'Naturals Ice Cream', 'naturals', ARRAY['naturals icecream','naturals'], 'food_dining', 'fd_desserts', 'offline', NULL),

-- Pubs & Bars (map to entertainment/ent_nightlife or food_dining/fd_pubs_bars)
('byg', 'Byg Brewski', 'byg brewski', ARRAY['brewski','byg'], 'food_dining', 'fd_pubs_bars', 'offline', NULL),
('social', 'Social', 'social', ARRAY['koramangala social','indiranagar social','hauz khas social'], 'food_dining', 'fd_pubs_bars', 'offline', NULL),
('hrc', 'Hard Rock Cafe', 'hardrock', ARRAY['hard rock cafe'], 'food_dining', 'fd_pubs_bars', 'offline', 'https://www.hardrockcafe.com'),

-- Fine Dining
('barbeque_nation', 'Barbeque Nation', 'barbeque nation', ARRAY['barbeque nation'], 'food_dining', 'fd_fine', 'offline', NULL),
('mainland_china', 'Mainland China', 'mainland china', ARRAY['mainland china'], 'food_dining', 'fd_fine', 'offline', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🛒 GROCERY & SUPERMARKETS
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
-- Online Groceries
('bigbasket', 'BigBasket', 'bigbasket', ARRAY['bigbasket','big basket'], 'groceries', 'groc_online', 'online', 'https://www.bigbasket.com'),
('blinkit', 'Blinkit', 'blinkit', ARRAY['blinkit','grofers'], 'groceries', 'groc_online', 'online', 'https://www.blinkit.com'),
('zepto', 'Zepto', 'zepto', ARRAY['zepto'], 'groceries', 'groc_online', 'online', 'https://www.zepto.com'),
('jiomart', 'JioMart', 'jiomart', ARRAY['jiomart','jio mart'], 'groceries', 'groc_online', 'online', 'https://www.jiomart.com'),

-- Hypermarkets & Supermarkets
('dmart', 'DMart', 'dmart', ARRAY['dmart','d mart'], 'groceries', 'groc_hyper', 'offline', 'https://www.dmartindia.com'),
('reliancefresh', 'Reliance Fresh', 'reliancefresh', ARRAY['reliance fresh','reliance smart'], 'groceries', 'groc_hyper', 'offline', NULL),
('more', 'More Supermarket', 'more', ARRAY['more supermarket','more retail'], 'groceries', 'groc_hyper', 'offline', NULL),
('spar', 'SPAR', 'spar', ARRAY['spar'], 'groceries', 'groc_hyper', 'offline', NULL),
('lulu', 'Lulu Hypermarket', 'lulu', ARRAY['lulu'], 'groceries', 'groc_hyper', 'offline', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🚕 RIDES / TRANSPORT
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
-- Ride Hailing
('uber', 'Uber', 'uber', ARRAY['uber','ubereats'], 'transport', 'tr_apps', 'online', 'https://www.uber.com'),
('ola', 'Ola', 'ola', ARRAY['ola','olacabs','ola money'], 'transport', 'tr_apps', 'online', 'https://www.olacabs.com'),
('rapido', 'Rapido', 'rapido', ARRAY['rapido'], 'transport', 'tr_apps', 'online', 'https://www.rapido.bike'),

-- Public Transport
('irctc', 'IRCTC', 'irctc', ARRAY['irctc','railway ticket','train ticket'], 'transport', 'tr_public', 'online', 'https://www.irctc.co.in'),
('redbus', 'RedBus', 'redbus', ARRAY['redbus'], 'transport', 'tr_public', 'online', 'https://www.redbus.in'),

-- Travel & Hotels
('makemytrip', 'MakeMyTrip', 'makemytrip', ARRAY['makemytrip','mmt'], 'transport', 'tr_travel', 'online', 'https://www.makemytrip.com'),
('goibibo', 'Goibibo', 'goibibo', ARRAY['goibibo'], 'transport', 'tr_travel', 'online', 'https://www.goibibo.com'),
('indigo', 'IndiGo', 'indigo', ARRAY['indigo'], 'transport', 'tr_travel', 'online', 'https://www.goindigo.in'),
('vistara', 'Vistara', 'vistara', ARRAY['vistara'], 'transport', 'tr_travel', 'online', 'https://www.airvistara.com'),
('air_india', 'Air India', 'air india', ARRAY['air india'], 'transport', 'tr_travel', 'online', 'https://www.airindia.in'),
('akasa_air', 'Akasa Air', 'akasa air', ARRAY['akasa'], 'transport', 'tr_travel', 'online', 'https://www.akasaair.com'),
('oyo', 'OYO', 'oyo', ARRAY['oyo rooms','oyo hotels'], 'transport', 'tr_lodging', 'online', 'https://www.oyorooms.com'),

-- Tolls
('toll', 'Toll / FASTag', 'toll', ARRAY['toll','fastag'], 'transport', 'tr_tolls', 'utility', NULL),
('nhai', 'NHAI FASTag', 'nhai', ARRAY['nhai','fastag'], 'transport', 'tr_tolls', 'utility', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 💳 WALLET / UPI APPS
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('gpay', 'Google Pay', 'gpay', ARRAY['gpay','google pay'], 'transfers_out', 'tr_out_wallet', 'online', 'https://pay.google.com'),
('phonepe', 'PhonePe', 'phonepe', ARRAY['phonepe','phone pe'], 'transfers_out', 'tr_out_wallet', 'online', 'https://www.phonepe.com'),
('paytm', 'Paytm', 'paytm', ARRAY['paytm'], 'transfers_out', 'tr_out_wallet', 'online', 'https://paytm.com'),
('amazonpay', 'Amazon Pay', 'amazonpay', ARRAY['amazon pay'], 'transfers_out', 'tr_out_wallet', 'online', 'https://pay.amazon.in')
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🛍 SHOPPING / GENERAL RETAIL
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
-- Online Marketplaces
('amazon', 'Amazon', 'amazon', ARRAY['amazon','amzn','amazon.in'], 'shopping', 'shop_marketplaces', 'online', 'https://www.amazon.in'),
('flipkart', 'Flipkart', 'flipkart', ARRAY['flipkart'], 'shopping', 'shop_marketplaces', 'online', 'https://www.flipkart.com'),
('meesho', 'Meesho', 'meesho', ARRAY['meesho'], 'shopping', 'shop_marketplaces', 'online', 'https://www.meesho.com'),

-- Fashion
('myntra', 'Myntra', 'myntra', ARRAY['myntra'], 'shopping', 'shop_clothing', 'online', 'https://www.myntra.com'),
('ajio', 'AJIO', 'ajio', ARRAY['ajio'], 'shopping', 'shop_clothing', 'online', 'https://www.ajio.com'),

-- Beauty
('nykaa', 'Nykaa', 'nykaa', ARRAY['nykaa'], 'shopping', 'shop_beauty', 'online', 'https://www.nykaa.com'),
('sephora', 'Sephora', 'sephora', ARRAY['sephora'], 'shopping', 'shop_beauty', 'offline', 'https://www.sephora.in'),

-- Electronics
('croma', 'Croma', 'croma', ARRAY['croma'], 'shopping', 'shop_electronics', 'offline', 'https://www.cromaretail.com'),
('reliance_digital', 'Reliance Digital', 'reliance digital', ARRAY['reliance digital'], 'shopping', 'shop_electronics', 'offline', 'https://www.reliancedigital.in'),
('vijaysales', 'Vijay Sales', 'vijay sales', ARRAY['vijay sales'], 'shopping', 'shop_electronics', 'offline', NULL),

-- Home & Kitchen
('ikea', 'IKEA', 'ikea', ARRAY['ikea'], 'shopping', 'shop_home_kitchen', 'offline', 'https://www.ikea.com/in'),
('pepperfry', 'Pepperfry', 'pepperfry', ARRAY['pepperfry'], 'shopping', 'shop_home_kitchen', 'online', 'https://www.pepperfry.com'),
('urban_company', 'Urban Company', 'urban company', ARRAY['urban company','urbancompany','uc'], 'shopping', 'shop_home_kitchen', 'online', 'https://www.urbancompany.com'),

-- Other Shopping
('archies', 'Archies', 'archies', ARRAY['archies'], 'shopping', 'shop_gifts', 'offline', NULL),
('crossword', 'Crossword', 'crossword', ARRAY['crossword'], 'shopping', 'shop_books_media', 'offline', NULL),
('decathlon', 'Decathlon', 'decathlon', ARRAY['decathlon'], 'shopping', 'shop_sports_outdoor', 'offline', 'https://www.decathlon.in'),
('hamleys', 'Hamleys', 'hamleys', ARRAY['hamleys'], 'shopping', 'shop_children_toys', 'offline', NULL),
('firstcry', 'FirstCry', 'firstcry', ARRAY['firstcry'], 'shopping', 'shop_children_toys', 'online', 'https://www.firstcry.com'),
('heads_up_tails', 'Heads Up For Tails', 'heads up for tails', ARRAY['tails','pet supplies'], 'shopping', 'shop_pet_supplies', 'offline', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 📺 OTT & ENTERTAINMENT
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('netflix', 'Netflix', 'netflix', ARRAY['netflix'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.netflix.com'),
('primevideo', 'Amazon Prime Video', 'prime video', ARRAY['prime video','amazon prime'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.primevideo.com'),
('hotstar', 'Disney+ Hotstar', 'disney hotstar', ARRAY['hotstar','disney','disney+ hotstar'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.hotstar.com'),
('sonyliv', 'Sony LIV', 'sony liv', ARRAY['sony liv','sonyliv'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.sonyliv.com'),
('zee5', 'Zee5', 'zee5', ARRAY['zee5'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.zee5.com'),
('jiocinema', 'JioCinema', 'jiocinema', ARRAY['jiocinema','jio cinema'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.jiocinema.com'),
('bookmyshow', 'BookMyShow', 'bookmyshow', ARRAY['bookmyshow'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.bookmyshow.com'),
('pvr', 'PVR Cinemas', 'pvr', ARRAY['pvr'], 'entertainment', 'ent_movies_ott', 'offline', 'https://www.pvrcinemas.com'),
('inox', 'INOX', 'inox', ARRAY['inox'], 'entertainment', 'ent_movies_ott', 'offline', 'https://www.inoxmovies.com'),

-- Music
('spotify', 'Spotify', 'spotify', ARRAY['spotify'], 'entertainment', 'ent_music', 'online', 'https://www.spotify.com'),
('gaana', 'Gaana', 'gaana', ARRAY['gaana'], 'entertainment', 'ent_music', 'online', 'https://www.gaana.com'),
('apple_music', 'Apple Music', 'apple music', ARRAY['apple music'], 'entertainment', 'ent_music', 'online', 'https://www.apple.com/apple-music'),
('wynk', 'Wynk Music', 'wynk', ARRAY['wynk'], 'entertainment', 'ent_music', 'online', 'https://wynk.in')
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🧾 UTILITIES (POWER, GAS, WATER, INTERNET)
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
-- Electricity
('tsspdcl', 'TSSPDCL', 'tsspdcl', ARRAY['tsspdcl'], 'utilities', 'util_electricity', 'utility', NULL),
('bescom', 'BESCOM', 'bescom', ARRAY['bescom'], 'utilities', 'util_electricity', 'utility', NULL),
('msedcl', 'MSEDCL', 'msedcl', ARRAY['msedcl'], 'utilities', 'util_electricity', 'utility', NULL),

-- Water
('bwssb', 'BWSSB', 'bwssb', ARRAY['bwssb'], 'utilities', 'util_water', 'utility', NULL),

-- Gas / LPG
('hp_gas', 'HP Gas', 'hpgas', ARRAY['hp gas','hpgas'], 'utilities', 'util_gas_lpg', 'utility', NULL),
('indane', 'Indane Gas', 'indane', ARRAY['indane'], 'utilities', 'util_gas_lpg', 'utility', NULL),
('bharatgas', 'Bharat Gas', 'bharatgas', ARRAY['bharat gas'], 'utilities', 'util_gas_lpg', 'utility', NULL),
('adani_gas', 'Adani Gas', 'adani gas', ARRAY['adani','png'], 'utilities', 'util_gas_lpg', 'utility', NULL),

-- Broadband / Internet
('airtel', 'Airtel Broadband', 'airtel', ARRAY['airtel','airtel broadband'], 'utilities', 'util_broadband', 'utility', 'https://www.airtel.in'),
('jiofiber', 'JioFiber', 'jiofiber', ARRAY['jio fiber','jiofiber'], 'utilities', 'util_broadband', 'utility', 'https://www.jio.com'),
('act', 'ACT Fibernet', 'act fibernet', ARRAY['act','actfibernet','act broadband'], 'utilities', 'util_broadband', 'utility', 'https://www.actcorp.in'),

-- Mobile / Telephone
('vi', 'Vi (Vodafone Idea)', 'vi', ARRAY['vi','vodafone idea'], 'utilities', 'util_mobile', 'utility', 'https://www.myvi.in'),

-- DTH / Cable
('tata_play', 'Tata Play', 'tata play', ARRAY['tataplay','dth'], 'utilities', 'util_dth_cable', 'utility', 'https://www.tataplay.com'),
('dishtv', 'DishTV', 'dishtv', ARRAY['dishtv'], 'utilities', 'util_dth_cable', 'utility', 'https://www.dishtv.in'),
('sun_direct', 'Sun Direct', 'sun direct', ARRAY['sun direct'], 'utilities', 'util_dth_cable', 'utility', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🏥 HEALTH & PHARMACY
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('pharmeasy', 'PharmEasy', 'pharmeasy', ARRAY['pharmeasy'], 'medical', 'med_pharma', 'online', 'https://www.pharmeasy.in'),
('tata1mg', '1mg', '1mg', ARRAY['tata 1mg','1mg'], 'medical', 'med_pharma', 'online', 'https://www.1mg.com'),
('apollo_pharmacy', 'Apollo Pharmacy', 'apollo pharmacy', ARRAY['apollo pharmacy','apollo pharmacy ltd'], 'medical', 'med_pharma', 'offline', 'https://www.apollopharmacy.in'),
('netmeds', 'Netmeds', 'netmeds', ARRAY['netmeds'], 'medical', 'med_pharma', 'online', 'https://www.netmeds.com'),
('practo', 'Practo', 'practo', ARRAY['practo'], 'medical', 'med_apps', 'online', 'https://www.practo.com')
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🧠 EDTECH
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('byjus', 'BYJU''S', 'byjus', ARRAY['byjus','byju''s'], 'education', 'edu_online', 'online', 'https://www.byjus.com'),
('unacademy', 'Unacademy', 'unacademy', ARRAY['unacademy'], 'education', 'edu_online', 'online', 'https://www.unacademy.com'),
('upgrad', 'UpGrad', 'upgrad', ARRAY['upgrad'], 'education', 'edu_online', 'online', 'https://www.upgrad.com'),
('coursera', 'Coursera', 'coursera', ARRAY['coursera'], 'education', 'edu_online', 'online', 'https://www.coursera.org')
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🏦 BANKS & CREDIT CARDS
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('hdfc', 'HDFC Bank', 'hdfc bank', ARRAY['hdfc','hdfc bank'], 'banks', 'bank_interest', 'banks', 'https://www.hdfcbank.com'),
('icici', 'ICICI Bank', 'icici bank', ARRAY['icici','icici bank'], 'banks', 'bank_interest', 'banks', 'https://www.icicibank.com'),
('sbi', 'SBI', 'state bank of india', ARRAY['sbi','sbi card','state bank'], 'banks', 'bank_interest', 'banks', 'https://www.sbi.co.in'),
('axis', 'AXIS Bank', 'axis bank', ARRAY['axis bank','axis'], 'banks', 'bank_interest', 'banks', 'https://www.axisbank.com'),
('kotak', 'Kotak Mahindra Bank', 'kotak mahindra bank', ARRAY['kotak','kotakbank'], 'banks', 'bank_interest', 'banks', 'https://www.kotak.com'),
('yes_bank', 'Yes Bank', 'yes bank', ARRAY['yesbank'], 'banks', 'bank_interest', 'banks', 'https://www.yesbank.in'),
('idfc', 'IDFC Bank', 'idfc bank', ARRAY['idfc','idfcbank'], 'banks', 'bank_interest', 'banks', 'https://www.idfcfirstbank.com'),
('rbl', 'RBL Bank', 'rbl bank', ARRAY['rbl','rblbank'], 'banks', 'bank_interest', 'banks', 'https://www.rblbank.com'),
('indusind', 'IndusInd Bank', 'indusind bank', ARRAY['indusind'], 'banks', 'bank_interest', 'banks', 'https://www.indusind.com'),
('federal', 'Federal Bank', 'federal bank', ARRAY['federalbank'], 'banks', 'bank_interest', 'banks', 'https://www.federalbank.co.in'),
('bob', 'Bank of Baroda', 'bank of baroda', ARRAY['bob','baroda'], 'banks', 'bank_interest', 'banks', 'https://www.bankofbaroda.in'),
('pnb', 'PNB', 'pnb', ARRAY['punjab national bank','pnbindia'], 'banks', 'bank_interest', 'banks', 'https://www.pnbindia.in'),
('union_bank', 'Union Bank', 'union bank', ARRAY['unionbank'], 'banks', 'bank_interest', 'banks', 'https://www.unionbankofindia.co.in')
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 💰 INVESTMENTS
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('zerodha', 'Zerodha', 'zerodha', ARRAY['zerodha'], 'investments_commitments', 'inv_stocks', 'online', 'https://www.zerodha.com'),
('groww', 'Groww', 'groww', ARRAY['groww'], 'investments_commitments', 'inv_stocks', 'online', 'https://www.groww.in'),
('upstox', 'Upstox', 'upstox', ARRAY['upstox'], 'investments_commitments', 'inv_stocks', 'online', 'https://www.upstox.com'),
('nps_trust', 'NPS Trust', 'nps trust', ARRAY['nps'], 'investments_commitments', 'inv_nps', 'online', NULL),
('sbi_mf', 'SBI Mutual Fund', 'sbi mf', ARRAY['sbi mutual fund','sbi mf'], 'investments_commitments', 'inv_sip', 'online', NULL),
('hdfc_mf', 'HDFC Mutual Fund', 'hdfc mf', ARRAY['hdfc mutual fund','hdfc mf'], 'investments_commitments', 'inv_sip', 'online', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🛡 INSURANCE / LOANS
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('lic', 'LIC', 'lic', ARRAY['lic'], 'insurance_premiums', 'ins_life', 'insurance', NULL),
('hdfc_life', 'HDFC Life', 'hdfc life', ARRAY['hdfc life'], 'insurance_premiums', 'ins_life', 'insurance', NULL),
('icici_lombard', 'ICICI Lombard', 'icici lombard', ARRAY['icici lombard'], 'insurance_premiums', 'ins_health', 'insurance', NULL),
('star_health', 'Star Health', 'star health', ARRAY['star health'], 'insurance_premiums', 'ins_health', 'insurance', NULL),
('acko', 'Acko', 'acko', ARRAY['acko'], 'insurance_premiums', 'ins_motor', 'insurance', NULL),
('bajaj_finserv', 'Bajaj Finserv', 'bajaj finserv', ARRAY['bajaj'], 'loans_payments', 'loan_personal', 'finance', NULL),
('hdfc_home_loan', 'HDFC Home Loan', 'hdfc home loan', ARRAY['hdfc home loan'], 'loans_payments', 'loan_home', 'finance', NULL),
('tata_motors_finance', 'Tata Motors Finance', 'tata motors finance', ARRAY['tata motors'], 'loans_payments', 'loan_car', 'finance', NULL),
('cashe', 'CASHe', 'cashe', ARRAY['cashe'], 'loans_payments', 'loan_personal', 'finance', NULL),
('cred', 'CRED', 'cred', ARRAY['cred'], 'loans_payments', 'loan_cc_bill', 'finance', 'https://www.cred.club')
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- ============================================================================
-- User-Corrected Merchants (from transaction categorization feedback)
-- ============================================================================
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
-- Credit Cards
('american_express', 'American Express', 'american express', ARRAY['american express','amex'], 'loans_payments', 'loan_cc_bill', 'finance', 'https://www.americanexpress.com'),

-- Groceries
('vijetha', 'Vijetha', 'vijetha', ARRAY['vijetha'], 'groceries', 'groc_hyper', 'offline', NULL),
('prs_fresh_chicken', 'PRS Fresh Chicken', 'prs fresh chicken', ARRAY['prs fresh chicken','prsfreshchicken'], 'groceries', 'groc_meat', 'offline', NULL),

-- Food & Dining
('marichi_hotels', 'Marichi Hotels', 'marichi hotels', ARRAY['marichi hotels','marichihotels'], 'food_dining', 'fd_pubs_bars', 'offline', NULL),
('hotel_crown_pan_shop', 'Hotel Crown Pan Shop', 'hotel crown pan shop', ARRAY['hotel crown pan shop','crown pan'], 'food_dining', 'fd_pan_shop', 'offline', NULL),
('fondof_coffee_lounge', 'Fondof Coffee Lounge', 'fondof coffee lounge', ARRAY['fondof coffee lounge','fondofcoffeelounge'], 'food_dining', 'fd_cafes', 'offline', NULL),

-- Pets
('allvet_pet_clinic', 'Allvet Pet Clinic', 'allvet pet clinic', ARRAY['allvet pet clinic','allvetpetclinic'], 'pets', 'pet_vaccine', 'offline', NULL),

-- Transport
('bpcl_premium_fuels', 'BPCL Premium Fuels', 'bpcl premium fuels', ARRAY['bpcl premium fuels','bpcl','bharat petroleum'], 'transport', 'tr_fuel', 'offline', 'https://www.bharatpetroleum.com'),

-- Loans
('razorpay_software', 'Razorpay Software Private', 'razorpaysoftwarepriv', ARRAY['razorpay software','razorpaysoftwarepriv'], 'loans_payments', 'loan_personal', 'finance', 'https://www.razorpay.com'),

-- Income (loan disbursement)
('kisetsusaisonfinan', 'Kisetsu Saison Finan', 'kisetsusaisonfinan', ARRAY['kisetsu saison finan','kisetsusaisonfinan'], 'income', 'inc_other', 'finance', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- ============================================================================
-- 6) Populate merchant_alias from brand_keywords
-- ============================================================================

INSERT INTO spendsense.merchant_alias (merchant_id, alias, normalized_alias)
SELECT 
    dm.merchant_id,
    unnest(dm.brand_keywords) AS alias,
    lower(unnest(dm.brand_keywords)) AS normalized_alias
FROM spendsense.dim_merchant dm
WHERE dm.brand_keywords IS NOT NULL
  AND array_length(dm.brand_keywords, 1) > 0
ON CONFLICT (merchant_id, normalized_alias) DO NOTHING;

-- Also add merchant_name and normalized_name as aliases
INSERT INTO spendsense.merchant_alias (merchant_id, alias, normalized_alias)
SELECT 
    merchant_id,
    merchant_name AS alias,
    normalized_name AS normalized_alias
FROM spendsense.dim_merchant
ON CONFLICT (merchant_id, normalized_alias) DO NOTHING;

-- ============================================================================
-- 7) Recreate foreign key constraints
-- ============================================================================

-- Recreate FK for txn_fact (merchant_id references dim_merchant.merchant_id)
ALTER TABLE spendsense.txn_fact
    ADD CONSTRAINT txn_fact_merchant_id_fkey
    FOREIGN KEY (merchant_id)
    REFERENCES spendsense.dim_merchant(merchant_id)
    ON DELETE SET NULL;

-- Recreate FK for txn_enriched (merchant_id references dim_merchant.merchant_id)
ALTER TABLE spendsense.txn_enriched
    ADD CONSTRAINT txn_enriched_merchant_id_fkey
    FOREIGN KEY (merchant_id)
    REFERENCES spendsense.dim_merchant(merchant_id)
    ON DELETE SET NULL;

-- Recreate FK for kpi_recurring_merchants_monthly (normalized_name references dim_merchant.normalized_name)
-- Note: This table might not exist, so we check first
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'spendsense' 
        AND table_name = 'kpi_recurring_merchants_monthly'
    ) THEN
        ALTER TABLE spendsense.kpi_recurring_merchants_monthly
            ADD CONSTRAINT fk_kpi_rec_merchants_dim_merchant
            FOREIGN KEY (merchant_name_norm)
            REFERENCES spendsense.dim_merchant(normalized_name)
            ON UPDATE CASCADE;
    END IF;
END $$;

COMMIT;

-- ============================================================================
-- Migration complete
-- ============================================================================
-- This migration:
-- 1. Creates enhanced dim_merchant schema with brand_keywords, category_code, etc.
-- 2. Creates merchant_alias table for flexible matching
-- 3. Populates 200+ India merchants with correct taxonomy
-- 4. Generates aliases from brand_keywords automatically
-- 5. Recreates foreign key constraints
-- ============================================================================

-- ============================================================================
-- 5) Insert Full India Merchant Dataset (200+ merchants)
-- ============================================================================
-- Mapped to correct taxonomy from migration 052

-- 🍔 FOOD & DINING (Delivery, Restaurants, Cafes)
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
-- Online Food Delivery
('swiggy', 'Swiggy', 'swiggy', ARRAY['swiggy','instamart','swig'], 'food_dining', 'fd_online', 'online', 'https://www.swiggy.com'),
('zomato', 'Zomato', 'zomato', ARRAY['zomato'], 'food_dining', 'fd_online', 'online', 'https://www.zomato.com'),
('eatsure', 'EatSure', 'eatsure', ARRAY['eatsure'], 'food_dining', 'fd_online', 'online', NULL),

-- Fast Food
('mcd', 'McDonalds', 'mcdonalds', ARRAY['mcdonalds','mcd'], 'food_dining', 'fd_quick_service', 'offline', 'https://www.mcdonalds.com'),
('kfc', 'KFC', 'kfc', ARRAY['kfc'], 'food_dining', 'fd_quick_service', 'offline', 'https://www.kfc.co.in'),
('burgerking', 'Burger King', 'burgerking', ARRAY['burgerking','burger king'], 'food_dining', 'fd_quick_service', 'offline', 'https://www.burgerking.in'),
('dominos', 'Domino''s Pizza', 'dominos', ARRAY['dominos','domino'], 'food_dining', 'fd_quick_service', 'offline', 'https://www.dominos.co.in'),
('pizzahut', 'Pizza Hut', 'pizzahut', ARRAY['pizza hut'], 'food_dining', 'fd_quick_service', 'offline', 'https://www.pizzahut.co.in'),
('wowmomo', 'Wow! Momo', 'wowmomo', ARRAY['wow momo','wow! momo'], 'food_dining', 'fd_quick_service', 'offline', NULL),

-- Cafes & Desserts
('starbucks', 'Starbucks', 'starbucks', ARRAY['starbucks'], 'food_dining', 'fd_cafes', 'offline', 'https://www.starbucks.in'),
('ccd', 'Cafe Coffee Day', 'ccd', ARRAY['ccd','cafe coffee day'], 'food_dining', 'fd_cafes', 'offline', 'https://www.cafecoffeeday.com'),
('theobroma', 'Theobroma', 'theobroma', ARRAY['theobroma'], 'food_dining', 'fd_desserts', 'offline', NULL),
('naturals', 'Naturals Ice Cream', 'naturals', ARRAY['naturals icecream','naturals'], 'food_dining', 'fd_desserts', 'offline', NULL),

-- Pubs & Bars (map to entertainment/ent_nightlife or food_dining/fd_pubs_bars)
('byg', 'Byg Brewski', 'byg brewski', ARRAY['brewski','byg'], 'food_dining', 'fd_pubs_bars', 'offline', NULL),
('social', 'Social', 'social', ARRAY['koramangala social','indiranagar social','hauz khas social'], 'food_dining', 'fd_pubs_bars', 'offline', NULL),
('hrc', 'Hard Rock Cafe', 'hardrock', ARRAY['hard rock cafe'], 'food_dining', 'fd_pubs_bars', 'offline', 'https://www.hardrockcafe.com'),

-- Fine Dining
('barbeque_nation', 'Barbeque Nation', 'barbeque nation', ARRAY['barbeque nation'], 'food_dining', 'fd_fine', 'offline', NULL),
('mainland_china', 'Mainland China', 'mainland china', ARRAY['mainland china'], 'food_dining', 'fd_fine', 'offline', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🛒 GROCERY & SUPERMARKETS
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
-- Online Groceries
('bigbasket', 'BigBasket', 'bigbasket', ARRAY['bigbasket','big basket'], 'groceries', 'groc_online', 'online', 'https://www.bigbasket.com'),
('blinkit', 'Blinkit', 'blinkit', ARRAY['blinkit','grofers'], 'groceries', 'groc_online', 'online', 'https://www.blinkit.com'),
('zepto', 'Zepto', 'zepto', ARRAY['zepto'], 'groceries', 'groc_online', 'online', 'https://www.zepto.com'),
('jiomart', 'JioMart', 'jiomart', ARRAY['jiomart','jio mart'], 'groceries', 'groc_online', 'online', 'https://www.jiomart.com'),

-- Hypermarkets & Supermarkets
('dmart', 'DMart', 'dmart', ARRAY['dmart','d mart'], 'groceries', 'groc_hyper', 'offline', 'https://www.dmartindia.com'),
('reliancefresh', 'Reliance Fresh', 'reliancefresh', ARRAY['reliance fresh','reliance smart'], 'groceries', 'groc_hyper', 'offline', NULL),
('more', 'More Supermarket', 'more', ARRAY['more supermarket','more retail'], 'groceries', 'groc_hyper', 'offline', NULL),
('spar', 'SPAR', 'spar', ARRAY['spar'], 'groceries', 'groc_hyper', 'offline', NULL),
('lulu', 'Lulu Hypermarket', 'lulu', ARRAY['lulu'], 'groceries', 'groc_hyper', 'offline', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🚕 RIDES / TRANSPORT
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
-- Ride Hailing
('uber', 'Uber', 'uber', ARRAY['uber','ubereats'], 'transport', 'tr_apps', 'online', 'https://www.uber.com'),
('ola', 'Ola', 'ola', ARRAY['ola','olacabs','ola money'], 'transport', 'tr_apps', 'online', 'https://www.olacabs.com'),
('rapido', 'Rapido', 'rapido', ARRAY['rapido'], 'transport', 'tr_apps', 'online', 'https://www.rapido.bike'),

-- Public Transport
('irctc', 'IRCTC', 'irctc', ARRAY['irctc','railway ticket','train ticket'], 'transport', 'tr_public', 'online', 'https://www.irctc.co.in'),
('redbus', 'RedBus', 'redbus', ARRAY['redbus'], 'transport', 'tr_public', 'online', 'https://www.redbus.in'),

-- Travel & Hotels
('makemytrip', 'MakeMyTrip', 'makemytrip', ARRAY['makemytrip','mmt'], 'transport', 'tr_travel', 'online', 'https://www.makemytrip.com'),
('goibibo', 'Goibibo', 'goibibo', ARRAY['goibibo'], 'transport', 'tr_travel', 'online', 'https://www.goibibo.com'),
('indigo', 'IndiGo', 'indigo', ARRAY['indigo'], 'transport', 'tr_travel', 'online', 'https://www.goindigo.in'),
('vistara', 'Vistara', 'vistara', ARRAY['vistara'], 'transport', 'tr_travel', 'online', 'https://www.airvistara.com'),
('air_india', 'Air India', 'air india', ARRAY['air india'], 'transport', 'tr_travel', 'online', 'https://www.airindia.in'),
('akasa_air', 'Akasa Air', 'akasa air', ARRAY['akasa'], 'transport', 'tr_travel', 'online', 'https://www.akasaair.com'),
('oyo', 'OYO', 'oyo', ARRAY['oyo rooms','oyo hotels'], 'transport', 'tr_lodging', 'online', 'https://www.oyorooms.com'),

-- Tolls
('toll', 'Toll / FASTag', 'toll', ARRAY['toll','fastag'], 'transport', 'tr_tolls', 'utility', NULL),
('nhai', 'NHAI FASTag', 'nhai', ARRAY['nhai','fastag'], 'transport', 'tr_tolls', 'utility', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 💳 WALLET / UPI APPS
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('gpay', 'Google Pay', 'gpay', ARRAY['gpay','google pay'], 'transfers_out', 'tr_out_wallet', 'online', 'https://pay.google.com'),
('phonepe', 'PhonePe', 'phonepe', ARRAY['phonepe','phone pe'], 'transfers_out', 'tr_out_wallet', 'online', 'https://www.phonepe.com'),
('paytm', 'Paytm', 'paytm', ARRAY['paytm'], 'transfers_out', 'tr_out_wallet', 'online', 'https://paytm.com'),
('amazonpay', 'Amazon Pay', 'amazonpay', ARRAY['amazon pay'], 'transfers_out', 'tr_out_wallet', 'online', 'https://pay.amazon.in')
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🛍 SHOPPING / GENERAL RETAIL
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
-- Online Marketplaces
('amazon', 'Amazon', 'amazon', ARRAY['amazon','amzn','amazon.in'], 'shopping', 'shop_marketplaces', 'online', 'https://www.amazon.in'),
('flipkart', 'Flipkart', 'flipkart', ARRAY['flipkart'], 'shopping', 'shop_marketplaces', 'online', 'https://www.flipkart.com'),
('meesho', 'Meesho', 'meesho', ARRAY['meesho'], 'shopping', 'shop_marketplaces', 'online', 'https://www.meesho.com'),

-- Fashion
('myntra', 'Myntra', 'myntra', ARRAY['myntra'], 'shopping', 'shop_clothing', 'online', 'https://www.myntra.com'),
('ajio', 'AJIO', 'ajio', ARRAY['ajio'], 'shopping', 'shop_clothing', 'online', 'https://www.ajio.com'),

-- Beauty
('nykaa', 'Nykaa', 'nykaa', ARRAY['nykaa'], 'shopping', 'shop_beauty', 'online', 'https://www.nykaa.com'),
('sephora', 'Sephora', 'sephora', ARRAY['sephora'], 'shopping', 'shop_beauty', 'offline', 'https://www.sephora.in'),

-- Electronics
('croma', 'Croma', 'croma', ARRAY['croma'], 'shopping', 'shop_electronics', 'offline', 'https://www.cromaretail.com'),
('reliance_digital', 'Reliance Digital', 'reliance digital', ARRAY['reliance digital'], 'shopping', 'shop_electronics', 'offline', 'https://www.reliancedigital.in'),
('vijaysales', 'Vijay Sales', 'vijay sales', ARRAY['vijay sales'], 'shopping', 'shop_electronics', 'offline', NULL),

-- Home & Kitchen
('ikea', 'IKEA', 'ikea', ARRAY['ikea'], 'shopping', 'shop_home_kitchen', 'offline', 'https://www.ikea.com/in'),
('pepperfry', 'Pepperfry', 'pepperfry', ARRAY['pepperfry'], 'shopping', 'shop_home_kitchen', 'online', 'https://www.pepperfry.com'),
('urban_company', 'Urban Company', 'urban company', ARRAY['urban company','urbancompany','uc'], 'shopping', 'shop_home_kitchen', 'online', 'https://www.urbancompany.com'),

-- Other Shopping
('archies', 'Archies', 'archies', ARRAY['archies'], 'shopping', 'shop_gifts', 'offline', NULL),
('crossword', 'Crossword', 'crossword', ARRAY['crossword'], 'shopping', 'shop_books_media', 'offline', NULL),
('decathlon', 'Decathlon', 'decathlon', ARRAY['decathlon'], 'shopping', 'shop_sports_outdoor', 'offline', 'https://www.decathlon.in'),
('hamleys', 'Hamleys', 'hamleys', ARRAY['hamleys'], 'shopping', 'shop_children_toys', 'offline', NULL),
('firstcry', 'FirstCry', 'firstcry', ARRAY['firstcry'], 'shopping', 'shop_children_toys', 'online', 'https://www.firstcry.com'),
('heads_up_tails', 'Heads Up For Tails', 'heads up for tails', ARRAY['tails','pet supplies'], 'shopping', 'shop_pet_supplies', 'offline', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 📺 OTT & ENTERTAINMENT
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('netflix', 'Netflix', 'netflix', ARRAY['netflix'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.netflix.com'),
('primevideo', 'Amazon Prime Video', 'prime video', ARRAY['prime video','amazon prime'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.primevideo.com'),
('hotstar', 'Disney+ Hotstar', 'disney hotstar', ARRAY['hotstar','disney','disney+ hotstar'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.hotstar.com'),
('sonyliv', 'Sony LIV', 'sony liv', ARRAY['sony liv','sonyliv'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.sonyliv.com'),
('zee5', 'Zee5', 'zee5', ARRAY['zee5'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.zee5.com'),
('jiocinema', 'JioCinema', 'jiocinema', ARRAY['jiocinema','jio cinema'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.jiocinema.com'),
('bookmyshow', 'BookMyShow', 'bookmyshow', ARRAY['bookmyshow'], 'entertainment', 'ent_movies_ott', 'online', 'https://www.bookmyshow.com'),
('pvr', 'PVR Cinemas', 'pvr', ARRAY['pvr'], 'entertainment', 'ent_movies_ott', 'offline', 'https://www.pvrcinemas.com'),
('inox', 'INOX', 'inox', ARRAY['inox'], 'entertainment', 'ent_movies_ott', 'offline', 'https://www.inoxmovies.com'),

-- Music
('spotify', 'Spotify', 'spotify', ARRAY['spotify'], 'entertainment', 'ent_music', 'online', 'https://www.spotify.com'),
('gaana', 'Gaana', 'gaana', ARRAY['gaana'], 'entertainment', 'ent_music', 'online', 'https://www.gaana.com'),
('apple_music', 'Apple Music', 'apple music', ARRAY['apple music'], 'entertainment', 'ent_music', 'online', 'https://www.apple.com/apple-music'),
('wynk', 'Wynk Music', 'wynk', ARRAY['wynk'], 'entertainment', 'ent_music', 'online', 'https://wynk.in')
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🧾 UTILITIES (POWER, GAS, WATER, INTERNET)
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
-- Electricity
('tsspdcl', 'TSSPDCL', 'tsspdcl', ARRAY['tsspdcl'], 'utilities', 'util_electricity', 'utility', NULL),
('bescom', 'BESCOM', 'bescom', ARRAY['bescom'], 'utilities', 'util_electricity', 'utility', NULL),
('msedcl', 'MSEDCL', 'msedcl', ARRAY['msedcl'], 'utilities', 'util_electricity', 'utility', NULL),

-- Water
('bwssb', 'BWSSB', 'bwssb', ARRAY['bwssb'], 'utilities', 'util_water', 'utility', NULL),

-- Gas / LPG
('hp_gas', 'HP Gas', 'hpgas', ARRAY['hp gas','hpgas'], 'utilities', 'util_gas_lpg', 'utility', NULL),
('indane', 'Indane Gas', 'indane', ARRAY['indane'], 'utilities', 'util_gas_lpg', 'utility', NULL),
('bharatgas', 'Bharat Gas', 'bharatgas', ARRAY['bharat gas'], 'utilities', 'util_gas_lpg', 'utility', NULL),
('adani_gas', 'Adani Gas', 'adani gas', ARRAY['adani','png'], 'utilities', 'util_gas_lpg', 'utility', NULL),

-- Broadband / Internet
('airtel', 'Airtel Broadband', 'airtel', ARRAY['airtel','airtel broadband'], 'utilities', 'util_broadband', 'utility', 'https://www.airtel.in'),
('jiofiber', 'JioFiber', 'jiofiber', ARRAY['jio fiber','jiofiber'], 'utilities', 'util_broadband', 'utility', 'https://www.jio.com'),
('act', 'ACT Fibernet', 'act fibernet', ARRAY['act','actfibernet','act broadband'], 'utilities', 'util_broadband', 'utility', 'https://www.actcorp.in'),

-- Mobile / Telephone
('vi', 'Vi (Vodafone Idea)', 'vi', ARRAY['vi','vodafone idea'], 'utilities', 'util_mobile', 'utility', 'https://www.myvi.in'),

-- DTH / Cable
('tata_play', 'Tata Play', 'tata play', ARRAY['tataplay','dth'], 'utilities', 'util_dth_cable', 'utility', 'https://www.tataplay.com'),
('dishtv', 'DishTV', 'dishtv', ARRAY['dishtv'], 'utilities', 'util_dth_cable', 'utility', 'https://www.dishtv.in'),
('sun_direct', 'Sun Direct', 'sun direct', ARRAY['sun direct'], 'utilities', 'util_dth_cable', 'utility', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🏥 HEALTH & PHARMACY
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('pharmeasy', 'PharmEasy', 'pharmeasy', ARRAY['pharmeasy'], 'medical', 'med_pharma', 'online', 'https://www.pharmeasy.in'),
('tata1mg', '1mg', '1mg', ARRAY['tata 1mg','1mg'], 'medical', 'med_pharma', 'online', 'https://www.1mg.com'),
('apollo_pharmacy', 'Apollo Pharmacy', 'apollo pharmacy', ARRAY['apollo pharmacy','apollo pharmacy ltd'], 'medical', 'med_pharma', 'offline', 'https://www.apollopharmacy.in'),
('netmeds', 'Netmeds', 'netmeds', ARRAY['netmeds'], 'medical', 'med_pharma', 'online', 'https://www.netmeds.com'),
('practo', 'Practo', 'practo', ARRAY['practo'], 'medical', 'med_apps', 'online', 'https://www.practo.com')
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🧠 EDTECH
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('byjus', 'BYJU''S', 'byjus', ARRAY['byjus','byju''s'], 'education', 'edu_online', 'online', 'https://www.byjus.com'),
('unacademy', 'Unacademy', 'unacademy', ARRAY['unacademy'], 'education', 'edu_online', 'online', 'https://www.unacademy.com'),
('upgrad', 'UpGrad', 'upgrad', ARRAY['upgrad'], 'education', 'edu_online', 'online', 'https://www.upgrad.com'),
('coursera', 'Coursera', 'coursera', ARRAY['coursera'], 'education', 'edu_online', 'online', 'https://www.coursera.org')
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🏦 BANKS & CREDIT CARDS
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('hdfc', 'HDFC Bank', 'hdfc bank', ARRAY['hdfc','hdfc bank'], 'banks', 'bank_interest', 'banks', 'https://www.hdfcbank.com'),
('icici', 'ICICI Bank', 'icici bank', ARRAY['icici','icici bank'], 'banks', 'bank_interest', 'banks', 'https://www.icicibank.com'),
('sbi', 'SBI', 'state bank of india', ARRAY['sbi','sbi card','state bank'], 'banks', 'bank_interest', 'banks', 'https://www.sbi.co.in'),
('axis', 'AXIS Bank', 'axis bank', ARRAY['axis bank','axis'], 'banks', 'bank_interest', 'banks', 'https://www.axisbank.com'),
('kotak', 'Kotak Mahindra Bank', 'kotak mahindra bank', ARRAY['kotak','kotakbank'], 'banks', 'bank_interest', 'banks', 'https://www.kotak.com'),
('yes_bank', 'Yes Bank', 'yes bank', ARRAY['yesbank'], 'banks', 'bank_interest', 'banks', 'https://www.yesbank.in'),
('idfc', 'IDFC Bank', 'idfc bank', ARRAY['idfc','idfcbank'], 'banks', 'bank_interest', 'banks', 'https://www.idfcfirstbank.com'),
('rbl', 'RBL Bank', 'rbl bank', ARRAY['rbl','rblbank'], 'banks', 'bank_interest', 'banks', 'https://www.rblbank.com'),
('indusind', 'IndusInd Bank', 'indusind bank', ARRAY['indusind'], 'banks', 'bank_interest', 'banks', 'https://www.indusind.com'),
('federal', 'Federal Bank', 'federal bank', ARRAY['federalbank'], 'banks', 'bank_interest', 'banks', 'https://www.federalbank.co.in'),
('bob', 'Bank of Baroda', 'bank of baroda', ARRAY['bob','baroda'], 'banks', 'bank_interest', 'banks', 'https://www.bankofbaroda.in'),
('pnb', 'PNB', 'pnb', ARRAY['punjab national bank','pnbindia'], 'banks', 'bank_interest', 'banks', 'https://www.pnbindia.in'),
('union_bank', 'Union Bank', 'union bank', ARRAY['unionbank'], 'banks', 'bank_interest', 'banks', 'https://www.unionbankofindia.co.in')
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 💰 INVESTMENTS
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('zerodha', 'Zerodha', 'zerodha', ARRAY['zerodha'], 'investments_commitments', 'inv_stocks', 'online', 'https://www.zerodha.com'),
('groww', 'Groww', 'groww', ARRAY['groww'], 'investments_commitments', 'inv_stocks', 'online', 'https://www.groww.in'),
('upstox', 'Upstox', 'upstox', ARRAY['upstox'], 'investments_commitments', 'inv_stocks', 'online', 'https://www.upstox.com'),
('nps_trust', 'NPS Trust', 'nps trust', ARRAY['nps'], 'investments_commitments', 'inv_nps', 'online', NULL),
('sbi_mf', 'SBI Mutual Fund', 'sbi mf', ARRAY['sbi mutual fund','sbi mf'], 'investments_commitments', 'inv_sip', 'online', NULL),
('hdfc_mf', 'HDFC Mutual Fund', 'hdfc mf', ARRAY['hdfc mutual fund','hdfc mf'], 'investments_commitments', 'inv_sip', 'online', NULL)
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- 🛡 INSURANCE / LOANS
INSERT INTO spendsense.dim_merchant (
    merchant_code, merchant_name, normalized_name, brand_keywords,
    category_code, subcategory_code, merchant_type, website
)
VALUES
('lic', 'LIC', 'lic', ARRAY['lic'], 'insurance_premiums', 'ins_life', 'insurance', NULL),
('hdfc_life', 'HDFC Life', 'hdfc life', ARRAY['hdfc life'], 'insurance_premiums', 'ins_life', 'insurance', NULL),
('icici_lombard', 'ICICI Lombard', 'icici lombard', ARRAY['icici lombard'], 'insurance_premiums', 'ins_health', 'insurance', NULL),
('star_health', 'Star Health', 'star health', ARRAY['star health'], 'insurance_premiums', 'ins_health', 'insurance', NULL),
('acko', 'Acko', 'acko', ARRAY['acko'], 'insurance_premiums', 'ins_motor', 'insurance', NULL),
('bajaj_finserv', 'Bajaj Finserv', 'bajaj finserv', ARRAY['bajaj'], 'loans_payments', 'loan_personal', 'finance', NULL),
('hdfc_home_loan', 'HDFC Home Loan', 'hdfc home loan', ARRAY['hdfc home loan'], 'loans_payments', 'loan_home', 'finance', NULL),
('tata_motors_finance', 'Tata Motors Finance', 'tata motors finance', ARRAY['tata motors'], 'loans_payments', 'loan_car', 'finance', NULL),
('cashe', 'CASHe', 'cashe', ARRAY['cashe'], 'loans_payments', 'loan_personal', 'finance', NULL),
('cred', 'CRED', 'cred', ARRAY['cred'], 'loans_payments', 'loan_cc_bill', 'finance', 'https://www.cred.club')
ON CONFLICT (merchant_code) DO UPDATE
SET merchant_name = EXCLUDED.merchant_name,
    normalized_name = EXCLUDED.normalized_name,
    brand_keywords = EXCLUDED.brand_keywords,
    category_code = EXCLUDED.category_code,
    subcategory_code = EXCLUDED.subcategory_code,
    merchant_type = EXCLUDED.merchant_type,
    website = EXCLUDED.website,
    updated_at = NOW();

-- ============================================================================
-- 6) Populate merchant_alias with dim_merchant and merchant_alias support
-- ============================================================================

CREATE OR REPLACE FUNCTION spendsense.fn_match_merchant(
    in_merchant_name TEXT,
    in_description   TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_merchant_raw   TEXT;
    v_merchant_norm  TEXT;
    v_desc_norm      TEXT;
    v_row            RECORD;
    v_result         JSONB;
    v_base_conf      NUMERIC(3,2);
BEGIN
    -- If no signal at all, bail out
    IF (in_merchant_name IS NULL OR btrim(in_merchant_name) = '')
       AND (in_description IS NULL OR btrim(in_description) = '') THEN
        RETURN NULL;
    END IF;

    -- Normalise merchant name (fallback to description if name empty)
    v_merchant_raw := COALESCE(in_merchant_name, in_description, '');
    v_merchant_norm := lower(regexp_replace(v_merchant_raw, '\s+', ' ', 'g'));  -- collapse spaces
    v_desc_norm := lower(regexp_replace(COALESCE(in_description, ''), '\s+', ' ', 'g'));

    -------------------------------------------------------------------------
    -- 1) EXACT MATCH on merchant_rules.merchant_name_norm (existing)
    -------------------------------------------------------------------------
    SELECT 
        mr.rule_id,
        mr.merchant_name_norm,
        mr.category_code,
        mr.subcategory_code,
        mr.confidence,
        1.0::NUMERIC AS sim,
        'exact'::TEXT AS match_kind
    INTO v_row
    FROM spendsense.merchant_rules mr
    WHERE mr.active = TRUE
      AND mr.merchant_name_norm = v_merchant_norm
    ORDER BY mr.priority DESC, mr.confidence DESC
    LIMIT 1;

    IF FOUND THEN
        v_base_conf := GREATEST(COALESCE(v_row.confidence, 0.90), 0.90);
        v_result := jsonb_build_object(
            'rule_id',            v_row.rule_id,
            'merchant_name_norm', v_row.merchant_name_norm,
            'category_code',      v_row.category_code,
            'subcategory_code',   v_row.subcategory_code,
            'confidence',         v_base_conf,
            'match_kind',         'exact'
        );
        RETURN v_result;
    END IF;

    -------------------------------------------------------------------------
    -- 2) EXACT MATCH on dim_merchant.normalized_name (NEW)
    -------------------------------------------------------------------------
    SELECT 
        dm.merchant_id,
        dm.merchant_code,
        dm.merchant_name,
        dm.normalized_name,
        dm.category_code,
        dm.subcategory_code,
        0.95::NUMERIC AS confidence,  -- High confidence for exact dim_merchant match
        1.0::NUMERIC AS sim,
        'exact_dim'::TEXT AS match_kind
    INTO v_row
    FROM spendsense.dim_merchant dm
    WHERE dm.active = TRUE
      AND dm.normalized_name = v_merchant_norm
    LIMIT 1;

    IF FOUND THEN
        v_result := jsonb_build_object(
            'merchant_id',        v_row.merchant_id::TEXT,
            'merchant_code',      v_row.merchant_code,
            'merchant_name_norm', v_row.normalized_name,
            'category_code',      v_row.category_code,
            'subcategory_code',   v_row.subcategory_code,
            'confidence',         v_row.confidence,
            'match_kind',         'exact_dim'
        );
        RETURN v_result;
    END IF;

    -------------------------------------------------------------------------
    -- 3) FUZZY MATCH using pg_trgm similarity on merchant_rules (existing)
    -------------------------------------------------------------------------
    SELECT 
        mr.rule_id,
        mr.merchant_name_norm,
        mr.category_code,
        mr.subcategory_code,
        mr.confidence,
        similarity(mr.merchant_name_norm, v_merchant_norm) AS sim,
        'fuzzy'::TEXT AS match_kind
    INTO v_row
    FROM spendsense.merchant_rules mr
    WHERE mr.active = TRUE
      AND similarity(mr.merchant_name_norm, v_merchant_norm) >= 0.40
    ORDER BY similarity(mr.merchant_name_norm, v_merchant_norm) DESC,
             mr.priority DESC,
             mr.confidence DESC
    LIMIT 1;

    IF FOUND THEN
        v_base_conf := LEAST(1.0,
                             COALESCE(v_row.confidence, 0.80)
                             + (v_row.sim * 0.20));
        v_result := jsonb_build_object(
            'rule_id',            v_row.rule_id,
            'merchant_name_norm', v_row.merchant_name_norm,
            'category_code',      v_row.category_code,
            'subcategory_code',   v_row.subcategory_code,
            'confidence',         v_base_conf,
            'match_kind',         'fuzzy'
        );
        RETURN v_result;
    END IF;

    -------------------------------------------------------------------------
    -- 4) FUZZY MATCH on dim_merchant.normalized_name (NEW)
    -------------------------------------------------------------------------
    SELECT 
        dm.merchant_id,
        dm.merchant_code,
        dm.merchant_name,
        dm.normalized_name,
        dm.category_code,
        dm.subcategory_code,
        similarity(dm.normalized_name, v_merchant_norm) AS sim,
        'fuzzy_dim'::TEXT AS match_kind
    INTO v_row
    FROM spendsense.dim_merchant dm
    WHERE dm.active = TRUE
      AND similarity(dm.normalized_name, v_merchant_norm) >= 0.40
    ORDER BY similarity(dm.normalized_name, v_merchant_norm) DESC
    LIMIT 1;

    IF FOUND THEN
        v_base_conf := LEAST(1.0, 0.80 + (v_row.sim * 0.20));
        v_result := jsonb_build_object(
            'merchant_id',        v_row.merchant_id::TEXT,
            'merchant_code',      v_row.merchant_code,
            'merchant_name_norm', v_row.normalized_name,
            'category_code',      v_row.category_code,
            'subcategory_code',   v_row.subcategory_code,
            'confidence',         v_base_conf,
            'match_kind',         'fuzzy_dim'
        );
        RETURN v_result;
    END IF;

    -------------------------------------------------------------------------
    -- 5) KEYWORD / BRAND_KEYWORDS MATCH in merchant_rules (existing)
    -------------------------------------------------------------------------
    SELECT 
        mr.rule_id,
        mr.merchant_name_norm,
        mr.category_code,
        mr.subcategory_code,
        mr.confidence,
        0.70::NUMERIC AS sim,
        'keyword'::TEXT AS match_kind
    INTO v_row
    FROM spendsense.merchant_rules mr
    WHERE mr.active = TRUE
      AND mr.brand_keywords IS NOT NULL
      AND EXISTS (
            SELECT 1
            FROM unnest(mr.brand_keywords) bk
            WHERE v_merchant_norm ILIKE '%' || lower(bk) || '%'
               OR v_desc_norm     ILIKE '%' || lower(bk) || '%'
      )
    ORDER BY mr.priority DESC, mr.confidence DESC
    LIMIT 1;

    IF FOUND THEN
        v_base_conf := LEAST(1.0, COALESCE(v_row.confidence, 0.70));
        v_result := jsonb_build_object(
            'rule_id',            v_row.rule_id,
            'merchant_name_norm', v_row.merchant_name_norm,
            'category_code',      v_row.category_code,
            'subcategory_code',   v_row.subcategory_code,
            'confidence',         v_base_conf,
            'match_kind',         'keyword'
        );
        RETURN v_result;
    END IF;

    -------------------------------------------------------------------------
    -- 6) KEYWORD MATCH in dim_merchant.brand_keywords (NEW)
    -------------------------------------------------------------------------
    SELECT 
        dm.merchant_id,
        dm.merchant_code,
        dm.merchant_name,
        dm.normalized_name,
        dm.category_code,
        dm.subcategory_code,
        0.75::NUMERIC AS confidence,
        'keyword_dim'::TEXT AS match_kind
    INTO v_row
    FROM spendsense.dim_merchant dm
    WHERE dm.active = TRUE
      AND dm.brand_keywords IS NOT NULL
      AND array_length(dm.brand_keywords, 1) > 0
      AND EXISTS (
            SELECT 1
            FROM unnest(dm.brand_keywords) bk
            WHERE v_merchant_norm ILIKE '%' || lower(bk) || '%'
               OR v_desc_norm     ILIKE '%' || lower(bk) || '%'
      )
    LIMIT 1;

    IF FOUND THEN
        v_result := jsonb_build_object(
            'merchant_id',        v_row.merchant_id::TEXT,
            'merchant_code',      v_row.merchant_code,
            'merchant_name_norm', v_row.normalized_name,
            'category_code',      v_row.category_code,
            'subcategory_code',   v_row.subcategory_code,
            'confidence',         v_row.confidence,
            'match_kind',         'keyword_dim'
        );
        RETURN v_result;
    END IF;

    -------------------------------------------------------------------------
    -- 7) ALIAS MATCH in merchant_alias (NEW) - handles UPI variations
    -------------------------------------------------------------------------
    SELECT 
        dm.merchant_id,
        dm.merchant_code,
        dm.merchant_name,
        dm.normalized_name,
        dm.category_code,
        dm.subcategory_code,
        0.85::NUMERIC AS confidence,  -- High confidence for alias match
        'alias'::TEXT AS match_kind
    INTO v_row
    FROM spendsense.merchant_alias ma
    JOIN spendsense.dim_merchant dm ON ma.merchant_id = dm.merchant_id
    WHERE dm.active = TRUE
      AND (
        ma.normalized_alias = v_merchant_norm
        OR ma.normalized_alias = ANY(string_to_array(v_merchant_norm || ' ' || v_desc_norm, ' '))
        OR v_merchant_norm ILIKE '%' || ma.normalized_alias || '%'
        OR v_desc_norm ILIKE '%' || ma.normalized_alias || '%'
      )
    LIMIT 1;

    IF FOUND THEN
        v_result := jsonb_build_object(
            'merchant_id',        v_row.merchant_id::TEXT,
            'merchant_code',      v_row.merchant_code,
            'merchant_name_norm', v_row.normalized_name,
            'category_code',      v_row.category_code,
            'subcategory_code',   v_row.subcategory_code,
            'confidence',         v_row.confidence,
            'match_kind',         'alias'
        );
        RETURN v_result;
    END IF;

    -------------------------------------------------------------------------
    -- No match
    -------------------------------------------------------------------------
    RETURN NULL;

END;
$$;

COMMENT ON FUNCTION spendsense.fn_match_merchant IS 
'Enhanced merchant matching: checks merchant_rules (pattern matching), dim_merchant (exact/fuzzy/keyword), and merchant_alias (variations). Returns JSONB with merchant details and confidence score.';

-- ============================================================================
-- Add GIN index on dim_merchant.normalized_name for fuzzy matching
-- ============================================================================
CREATE INDEX IF NOT EXISTS ix_dim_merchant_trgm
    ON spendsense.dim_merchant
    USING gin (normalized_name gin_trgm_ops)
    WHERE active = TRUE;


-- ============================================================================
-- Add GIN index on dim_merchant.normalized_name for fuzzy matching
-- ============================================================================
CREATE INDEX IF NOT EXISTS ix_dim_merchant_trgm
    ON spendsense.dim_merchant
    USING gin (normalized_name gin_trgm_ops)
    WHERE active = TRUE;

COMMIT;

-- ============================================================================
-- Migration complete
-- ============================================================================
