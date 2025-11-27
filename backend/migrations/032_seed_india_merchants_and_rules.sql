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

