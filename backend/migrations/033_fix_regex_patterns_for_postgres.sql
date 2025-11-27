-- ============================================================================
-- Fix Regex Patterns for PostgreSQL
-- 1. Remove (?i) flags since we're using ~* for case-insensitive matching
-- 2. Replace \b (not supported) with \y (PostgreSQL word boundary)
-- PostgreSQL's ~* operator is case-insensitive, so (?i) is redundant
-- PostgreSQL uses \y for word boundaries, not \b
-- ============================================================================

BEGIN;

-- Update all merchant rules to remove (?i) flag and replace \b with \y
UPDATE spendsense.merchant_rules
SET pattern_regex = REPLACE(REPLACE(pattern_regex, '(?i)', ''), '\b', '\y')
WHERE pattern_regex LIKE '%(?i)%' OR pattern_regex LIKE '%\\b%';

COMMIT;

