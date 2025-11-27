# augment_rules.md
## Monytix Augment Rules

### Global System Rules
- Maintain system boundaries across SpendSense, Goals, BudgetPilot, GoalCompass, MoneyMoments, Realtime Ingestion, SSE, Auth.
- Never mutate canonical transaction data; use overrides.
- All writes must be idempotent using hashes and UPSERT.
- Use unified error envelope.
- Timestamps must be TIMESTAMPTZ (UTC).
- Publish SSE events after every material change.

### SpendSense Rules
- Hash-based dedupe using sha256(user_id + posted_at + amount + currency + raw_description).
- Categorization precedence: bank patterns → merchant rules → keyword rules → fallback.
- Negative = expense, positive = income.
- Categorization lives only in txn_enriched and txn_override.

### Goals Rules
- Recompute priority_rank on any update.
- Default horizon mapping: short=+1y, medium=+3y, long=+7y.
- Mandatory categories get +30 safety weight automatically.

### BudgetPilot Rules
- Must always return exactly 3 recommendations.
- Balanced (50/30/20) must always appear.
- Committed budget must expand into per-goal allocations.
- Use last 3 months average income for calculations.

### GoalCompass Rules
- Actual contributions must be attributed pro‑rata.
- Milestones (25/50/75/100%) trigger once only.
- progress>=100% automatically completes goal.

### MoneyMoments Rules
- Max 1 nudge per 24h.
- Muted categories block nudges entirely.
- Deliver nudge only if: rule match + no suppression + cooldown cleared.
- Must write to delivery_log before SSE.

### Realtime Ingestion Rules
- Validate Gmail OIDC tokens.
- Always fetch via Gmail History API; never parse push body directly.
- Parser output must include: provider, event_type, amount, posted_at, merchant, reference, account_hint.
- Email-derived events must go to txn_staging before normalization.

### SSE Rules
- Only send JSON event messages.
- Publish to Redis channel user:{user_id}.

### Auth Rules
- All endpoints except Gmail/Outlook push require Supabase JWT.
- Backend is fully stateless.

### Database Rules
- All PKs = UUID.
- Use UPSERT for updates.
- All money amounts = NUMERIC(14,2).
- Views must be deterministic.

### Logging/Observability Rules
- Log batch_id, user_id, stage, status, duration.
- Parser errors must not interrupt ingestion.

### Infrastructure Rules
- All ingestion endpoints must be idempotent.
- No synchronous parsing; always async queue-based pipeline.

### Testing Rules
- Unit + integration + E2E must exist for each module.
- CSV tests must include malformed rows, missing headers, duplicates.
