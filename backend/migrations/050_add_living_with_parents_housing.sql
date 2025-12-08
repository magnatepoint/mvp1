-- ============================================================================
-- Migration: Add "living_with_parents" to housing status options
-- ============================================================================
BEGIN;

-- Update the CHECK constraint on goal.user_life_context.housing
ALTER TABLE goal.user_life_context
  DROP CONSTRAINT IF EXISTS user_life_context_housing_check;

ALTER TABLE goal.user_life_context
  ADD CONSTRAINT user_life_context_housing_check
  CHECK (housing IN ('rent', 'own_mortgage', 'own_nomortgage', 'living_with_parents'));

COMMIT;

