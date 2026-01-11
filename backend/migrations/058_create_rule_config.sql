BEGIN;

-- Optional: Dynamic rule configuration table for runtime rule management
CREATE TABLE IF NOT EXISTS goal.rule_config (
    rule_name VARCHAR(64) PRIMARY KEY,
    enabled BOOLEAN NOT NULL DEFAULT true,
    priority INT NOT NULL DEFAULT 100,
    config JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Insert default configurations for existing rules
INSERT INTO goal.rule_config (rule_name, enabled, priority)
VALUES
    ('surplus_income', true, 20),
    ('overspending', true, 30),
    ('drift_rule', true, 40)
ON CONFLICT (rule_name) DO NOTHING;

COMMIT;

