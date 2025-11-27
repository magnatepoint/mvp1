---
type: "always_apply"
---

# 10_acceptance_criteria.md
**Module:** Acceptance Criteria & Test Coverage  
**Version:** 1.0  
**Owner:** QA Engineering / Product Architecture  
**Prepared by:** Monytix Team  

---

# 1. Overview

This module defines the **Acceptance Criteria (AC)** and **Test Coverage Requirements** for the entire Monytix MVP platform:

- SpendSense  
- Goals  
- BudgetPilot  
- GoalCompass  
- MoneyMoments  
- Realtime Ingestion  
- SSE Notifications  
- Infrastructure-level behaviors  

All criteria must pass before feature sign-off.

---

# 2. SpendSense – Acceptance Criteria

## AC-SS-1: CSV Upload
- Uploading a valid CSV must:
  - create `upload_batch`
  - populate `txn_staging`
  - start normalization + categorization Celery tasks  
  **Expected:** API returns 200 + batch_id.

## AC-SS-2: Deduplication
- Re-uploading the **same** CSV:
  - must not create duplicate rows in `txn_fact`
  - new processing result: `0 new transactions`
  - `hash` uniqueness must prevent all duplicates.

## AC-SS-3: Normalization
- Invalid dates → rejected  
- Valid transactions → canonical fields set  
- Amount signs must follow:
  - debit → negative  
  - credit → positive

## AC-SS-4: Categorization Coverage
- At least 90% of transactions must have a category/subcategory assigned with starter rule-set.

## AC-SS-5: User Overrides
- Overriding category:
  - must modify `txn_override` only
  - view must refresh via `vw_txn_effective`
  - removing override returns system suggestion.

## AC-SS-6: Transaction Listing
- Must return:
  - correct month filtering
  - correct totals
  - pagination correctness.

---

# 3. Goals – Acceptance Criteria

## AC-GO-1: Life Context
- User cannot submit goals until life context is valid.

## AC-GO-2: Catalog
- Catalog returned must:
  - contain all seeded categories
  - respect display_order.

## AC-GO-3: Goal Detail Validation
- estimated_cost > 0  
- target_date >= today  
- importance 1–5  

## AC-GO-4: Linked Transaction Type
- Must match `policy_linked_txn_type` unless user overrides.

## AC-GO-5: Priority Score
- Mandatory goals must always score +30  
- Rank must always produce:
  - rank 1 → highest priority goal
  - ties resolved by soonest target_date.

## AC-GO-6: Data Persistence
- user_goals_master must reflect correctly:
  - new goals
  - updates
  - archives (soft delete)

---

# 4. BudgetPilot – Acceptance Criteria

## AC-BP-1: Recommendation Count
- Always returns **exactly 3** recommended plans.

## AC-BP-2: Template Eligibility
- Templates must be included/excluded using rules:
  - emergency goals → emergency template  
  - debt goals → debt template  
  - high wants% → wants-control variant  

## AC-BP-3: Allocation Sum
`savings_budget = needs + wants + savings`  
Sum must equal income.

## AC-BP-4: Goal Allocation
- Allocation weights must:
  - reflect priority_rank
  - reflect urgency
  - reflect funding gap

## AC-BP-5: Commit Behavior
- Committing a plan must:
  - write record in `user_budget_commit`
  - expand into `user_budget_commit_goal_alloc`
  - reflect in monthly tracking.

---

# 5. GoalCompass – Acceptance Criteria

## AC-GC-1: Planned Contribution
- Planned amounts per goal must:
  - equal savings_budget per month.

## AC-GC-2: Actual Contribution Attribution
- Must follow pro-rata logic:
  `actual_alloc = (planned / total_planned) * actual_total`

## AC-GC-3: Snapshot Accuracy
- cumulative progress must equal sum(actual contributions).

## AC-GC-4: Milestones
- Once milestone reached:
  - record must appear in `user_goal_milestone_status`
  - must not duplicate in future months.

## AC-GC-5: Completion
- progress >= 100% → goal.status = completed

---

# 6. MoneyMoments – Acceptance Criteria

## AC-MM-1: Rule Matching
- If user meets rule conditions → candidate must be generated.

## AC-MM-2: Suppression
- User must not receive:
  - more than 1 nudge in 24 hours  
  - nudges from muted categories.

## AC-MM-3: Delivery
- Nudge must appear in:
  - delivery_log table
  - SSE feed
  - frontend feed UI

## AC-MM-4: Interaction Logging
- Clicking a nudge must log an interaction row.

---

# 7. Realtime Email Ingestion – Acceptance Criteria

## Gmail

### AC-RT-G-1: Gmail Watch
- Gmail watch creation must succeed with valid expiration timestamp.

### AC-RT-G-2: Pub/Sub Push
- Incoming Gmail notification must:
  - validate OIDC token
  - queue history processing task.

### AC-RT-G-3: History Processing
- All new emails since last historyId must be processed.
- No duplicates when history replay occurs.

---

## Outlook

### AC-RT-O-1: Subscription Validation
- Graph subscription must be refreshed before expiration.

### AC-RT-O-2: Webhook
- Webhook validation handshake must succeed.
- New message must be pulled via Graph & stored in `email_raw`.

---

## Email Parsing

### AC-RT-P-1: Parser Accuracy
- For supported providers, parser must correctly extract:
  - amount  
  - merchant  
  - posted_at  
  - event_type  
  - account_hint  

### AC-RT-P-2: Parser Errors
- Any parsing error must:
  - be written to `email_parse_logs`
  - not break ingestion pipeline

---

# 8. Realtime Notifications (SSE)

## AC-SSE-1: Stream Authentication
- SSE must refuse invalid JWT.

## AC-SSE-2: Event Delivery
- For every:
  - new transaction  
  - nudge  
  - goal update  
  - budget change  
  → user must receive SSE event.

## AC-SSE-3: Latency
- Email → UI event < 2 seconds.

---

# 9. Infrastructure & Non-Functional Criteria

## AC-INF-1: Performance
- 10k concurrent users:
  - API < 300ms p95
  - SSE < 500ms p95

## AC-INF-2: Scalability
- Pipeline must support:
  - 5k email events/user/month  
  - 100k users  

## AC-INF-3: Security
- All sensitive data encrypted at rest  
- OAuth2 tokens encrypted  
- Supabase JWT verified for every request  
- Public ingestion endpoints protected via Google/MS signatures  

## AC-INF-4: Idempotency
- CSV re-upload produces no duplicates  
- Email re-delivery produces no duplicate events  

---

# 10. End-to-End Acceptance (UAT Scenarios)

## Scenario 1 — User uploads CSV
**Expected:**  
- Pipeline processes  
- Categorization applied  
- Dashboard updates  
- No duplicates when re-uploading same file  

---

## Scenario 2 — User receives bank email
**Expected:**  
- Email ingestion picks it up  
- Parser extracts event  
- Transaction appears in dashboard within 2 seconds  
- SSE notification delivered  

---

## Scenario 3 — User sets goals
**Expected:**  
- Rank calculation correct  
- Linked txn type correct  
- Display in UI sorted by rank  

---

## Scenario 4 — Budget recommendation
**Expected:**  
- 3 plans returned  
- Balanced plan always present  
- Goal-priority plan present if goals ≥ 3  

---

## Scenario 5 — Monthly snapshot
**Expected:**  
- GoalCompass snapshot created  
- Milestones updated  
- Progress correct  

---

## Scenario 6 — Behavior nudge
**Expected:**  
- Dining overspend triggers nudge  
- Nudge delivered via SSE  
- Feed updated  

---

# END OF MODULE 10 – Acceptance Criteria
