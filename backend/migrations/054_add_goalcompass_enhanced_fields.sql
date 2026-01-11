-- ============================================================================
-- Migration: Add enhanced Goal Compass fields
-- Version: 054
-- Description: Adds fields for enhanced goal planning, prioritization, and life context
-- ============================================================================
BEGIN;

-- Add fields to goal.user_goals_master
ALTER TABLE goal.user_goals_master
  ADD COLUMN IF NOT EXISTS is_must_have BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS timeline_flexibility VARCHAR(20) CHECK (timeline_flexibility IN ('rigid', 'somewhat_flexible', 'flexible')),
  ADD COLUMN IF NOT EXISTS risk_profile_for_goal VARCHAR(20) CHECK (risk_profile_for_goal IN ('conservative', 'balanced', 'aggressive'));

-- Add fields to goal.user_life_context
ALTER TABLE goal.user_life_context
  ADD COLUMN IF NOT EXISTS monthly_investible_capacity NUMERIC(14,2) CHECK (monthly_investible_capacity >= 0),
  ADD COLUMN IF NOT EXISTS total_monthly_emi_obligations NUMERIC(14,2) CHECK (total_monthly_emi_obligations >= 0),
  ADD COLUMN IF NOT EXISTS risk_profile_overall VARCHAR(20) CHECK (risk_profile_overall IN ('conservative', 'balanced', 'aggressive')),
  ADD COLUMN IF NOT EXISTS review_frequency VARCHAR(20) CHECK (review_frequency IN ('monthly', 'quarterly', 'yearly')) DEFAULT 'quarterly',
  ADD COLUMN IF NOT EXISTS notify_on_drift BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS auto_adjust_on_income_change BOOLEAN NOT NULL DEFAULT FALSE;

COMMIT;

