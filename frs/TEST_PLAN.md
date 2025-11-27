# Monytix – Test Plan (MVP)

This test plan maps Module 10 acceptance criteria to concrete test suites and responsibilities.

## 1. Test Types

- Unit tests (backend + frontend)
- Integration tests (API + DB + queue)
- E2E tests (critical flows)
- Performance tests (key endpoints)

## 2. Coverage by Module

### 2.1 SpendSense

- Unit:
  - Normalization functions (amount parsing, date parsing, hash creation).
  - Categorization rules (keyword → category mapping).
- Integration:
  - CSV upload → txn_staging → txn_fact → txn_enriched.
  - Override behavior via `/v1/transactions/override`.
- E2E:
  - User uploads CSV → sees categorized transactions in UI.
  - Re-upload same CSV → no duplicates.

### 2.2 Goals

- Unit:
  - Priority score calculation logic.
  - linked_txn_type derivation from goal_category_master.
- Integration:
  - `/v1/goals/submit` → user_goals_master rows created.
- E2E:
  - User sets 3 goals → sees ordered list with correct ranks.

### 2.3 BudgetPilot

- Unit:
  - Template eligibility functions.
  - Plan allocation calculations.
- Integration:
  - `/v1/budget/recommendations` returns 3 plans.
  - `/v1/budget/commit` writes commit + goal_alloc tables.
- E2E:
  - User accepts plan → GoalCompass uses allocations.

### 2.4 GoalCompass

- Unit:
  - Contribution attribution function.
  - Milestone detection thresholds.
- Integration:
  - Monthly job produces goal_compass_snapshot rows.
- E2E:
  - User sees correct progress % and ETA on UI.

### 2.5 MoneyMoments

- Unit:
  - Rule evaluator for mm_nudge_rule_master.
  - Suppression & cooldown logic.
- Integration:
  - mm_signal_daily job wires from SpendSense/BudgetPilot/GoalCompass.
  - Nudge candidate → delivery → feed API.
- E2E:
  - Dining overspend scenario triggers exactly 1 nudge.

### 2.6 Realtime Ingestion

- Unit:
  - Email parser for typical bank patterns.
- Integration:
  - Gmail/Outlook webhooks → email_raw → email_event → txn_staging.
- E2E:
  - Test email injection → transaction appears in UI swiftly (<2s).

## 3. Performance Tests

- Target: 10k concurrent users, p95 latency < 300ms for key APIs.
- CSV upload for 1000 rows within 3 seconds.

## 4. Regression Strategy

- Maintain regression suite on:
  - ingestion pipeline
  - SSE events
  - critical business flows (goals, budget commit, nudge triggers)

## 5. Tools

- pytest, httpx, locust/k6, Playwright or Cypress (optional).

All new features must be mapped to Module 10 criteria and covered here.
