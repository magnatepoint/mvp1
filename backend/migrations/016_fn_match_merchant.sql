-- ============================================================================
-- Migration 016: Add Intelligent Merchant Matching Function
-- 
-- Creates fn_match_merchant() function that uses:
-- 1. Exact match on merchant_name_norm (fastest, highest confidence)
-- 2. Fuzzy match using pg_trgm similarity (handles typos/variations)
-- 3. Keyword match using brand_keywords array (flexible brand matching)
--
-- This replaces the inefficient CROSS JOIN approach in pipeline.py
-- ============================================================================

BEGIN;

SET search_path TO spendsense, public, extensions;

-- ============================================================================
-- 1) Enable pg_trgm extension for fuzzy text matching
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================================
-- 2) Add GIN indexes for efficient fuzzy matching
-- ============================================================================
-- Note: These indexes may already exist from migration 053, but we ensure they're here

-- GIN index for fuzzy matching on merchant_name_norm
CREATE INDEX IF NOT EXISTS ix_merchant_rules_trgm
    ON spendsense.merchant_rules
    USING gin (merchant_name_norm gin_trgm_ops);

-- GIN index for brand_keywords array searches (already exists from 053, but ensure it)
CREATE INDEX IF NOT EXISTS ix_merchant_rules_brand_keywords
    ON spendsense.merchant_rules
    USING gin (brand_keywords)
    WHERE brand_keywords IS NOT NULL;

-- Composite index for active + priority lookups
CREATE INDEX IF NOT EXISTS ix_merchant_rules_active_priority
    ON spendsense.merchant_rules (active, priority DESC)
    WHERE active = TRUE;

-- ============================================================================
-- 3) Core function: fn_match_merchant
-- ============================================================================
/*
    fn_match_merchant
    
    Input:
      in_merchant_name  - raw merchant name (from parser/txn_fact.merchant_name_norm)
      in_description    - optional txn description (for keyword matching)
    
    Output (JSONB or NULL):
      {
        "rule_id": "uuid-here",
        "merchant_name_norm": "swiggy",
        "category_code": "food_dining",
        "subcategory_code": "fd_online",
        "confidence": 0.95,
        "match_kind": "exact" | "fuzzy" | "keyword"
      }
    
    Matching Strategy:
      1. EXACT: Direct match on merchant_name_norm (confidence: 0.90-1.0)
      2. FUZZY: pg_trgm similarity >= 0.40 (confidence: 0.80 + similarity boost)
      3. KEYWORD: brand_keywords array search (confidence: 0.70)
*/

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
    -- 1) EXACT MATCH on merchant_name_norm
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
    -- 2) FUZZY MATCH using pg_trgm similarity on merchant_name_norm
    --    threshold ~0.4 is usually good for Indian brands
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
        -- combine rule confidence with similarity
        v_base_conf := LEAST(1.0,
                             COALESCE(v_row.confidence, 0.80)
                             + (v_row.sim * 0.20)); -- bump a bit by similarity
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
    -- 3) KEYWORD / BRAND_KEYWORDS MATCH
    --    - search in merchant_name_norm AND description for any brand keyword
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
    -- No match
    -------------------------------------------------------------------------
    RETURN NULL;

END;
$$;

COMMENT ON FUNCTION spendsense.fn_match_merchant IS 
'Matches merchant names using exact, fuzzy (pg_trgm), and keyword matching. Returns JSONB with rule details and confidence score.';

COMMIT;

