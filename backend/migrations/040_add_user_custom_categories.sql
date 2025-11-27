-- ============================================================================
-- Migration: Allow users to create custom categories and subcategories
-- ============================================================================

BEGIN;

-- Add user_id to dim_category to track custom categories
ALTER TABLE spendsense.dim_category
ADD COLUMN IF NOT EXISTS user_id UUID,
ADD COLUMN IF NOT EXISTS is_custom BOOLEAN NOT NULL DEFAULT FALSE;

-- Add user_id to dim_subcategory to track custom subcategories
ALTER TABLE spendsense.dim_subcategory
ADD COLUMN IF NOT EXISTS user_id UUID,
ADD COLUMN IF NOT EXISTS is_custom BOOLEAN NOT NULL DEFAULT FALSE;

-- Update unique constraint to allow same category_code for different users (custom only)
-- System categories (user_id IS NULL) must be unique globally
-- Custom categories (user_id IS NOT NULL) must be unique per user
-- We'll use a unique index with a WHERE clause for system categories
-- and a composite unique index for custom categories
DROP INDEX IF EXISTS spendsense.dim_category_category_code_key;
CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_category_code_system 
ON spendsense.dim_category(category_code) 
WHERE user_id IS NULL;
-- Composite unique index for custom categories (category_code + user_id)
CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_category_code_user 
ON spendsense.dim_category(category_code, user_id) 
WHERE user_id IS NOT NULL;

-- Similar for subcategories
DROP INDEX IF EXISTS spendsense.dim_subcategory_subcategory_code_key;
CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_subcategory_code_system 
ON spendsense.dim_subcategory(subcategory_code) 
WHERE user_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_subcategory_code_user 
ON spendsense.dim_subcategory(subcategory_code, user_id) 
WHERE user_id IS NOT NULL;

-- Add foreign key constraint for user_id (optional, can be NULL for system categories)
-- Note: This assumes users table exists in Supabase auth schema
-- ALTER TABLE spendsense.dim_category
-- ADD CONSTRAINT fk_dim_category_user 
-- FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ============================================================================
-- ML Model Training Tracking
-- ============================================================================

CREATE TABLE IF NOT EXISTS spendsense.ml_model_version (
    model_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,  -- NULL for global model, user_id for user-specific model
    model_type VARCHAR(32) NOT NULL CHECK (model_type IN ('category', 'subcategory', 'combined')),
    version INTEGER NOT NULL,
    training_samples INTEGER NOT NULL DEFAULT 0,
    accuracy NUMERIC(5,4),
    trained_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    model_path TEXT,  -- Path to serialized model file
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB DEFAULT '{}'::jsonb,
    UNIQUE (user_id, model_type, version)
);

CREATE INDEX IF NOT EXISTS idx_ml_model_type_active 
ON spendsense.ml_model_version(model_type, is_active, trained_at DESC);

-- Training feedback from user overrides
CREATE TABLE IF NOT EXISTS spendsense.ml_training_feedback (
    feedback_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    txn_id UUID NOT NULL REFERENCES spendsense.txn_fact(txn_id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    original_category_code VARCHAR(32),
    original_subcategory_code VARCHAR(48),
    corrected_category_code VARCHAR(32) NOT NULL,
    corrected_subcategory_code VARCHAR(48),
    merchant_name_norm VARCHAR(128),
    description TEXT,
    amount NUMERIC(14,2),
    direction VARCHAR(8),
    feedback_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    used_in_training BOOLEAN NOT NULL DEFAULT FALSE,
    model_version INTEGER
);

CREATE INDEX IF NOT EXISTS idx_ml_feedback_user_time 
ON spendsense.ml_training_feedback(user_id, feedback_at DESC);
CREATE INDEX IF NOT EXISTS idx_ml_feedback_training 
ON spendsense.ml_training_feedback(used_in_training, feedback_at);

COMMIT;

