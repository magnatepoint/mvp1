# Monytix – Epics & Task Breakdown

This document defines implementation epics and concrete tasks for Augment and engineers.

## Epic 1 – Core SpendSense Pipeline

**Goal:** Ingest CSV + manual transactions, normalize, categorize, and expose KPIs.

- Task 1.1 – Set up FastAPI project skeleton
  - Create `backend/app/main.py`, health endpoint, base config.
- Task 1.2 – Implement PostgreSQL + MongoDB connectors
  - `db/postgres.py`, `db/mongo.py` with connection lifecycle.
- Task 1.3 – Implement CSV upload endpoint
  - `/v1/transactions/upload` with batch tracking.
- Task 1.4 – Implement `txn_staging` persistence in MongoDB
- Task 1.5 – Implement normalization job → `txn_fact`
  - Hash-based dedupe.
- Task 1.6 – Implement categorization engine → `txn_enriched`
- Task 1.7 – Implement `txn_override` + `vw_txn_effective`
- Task 1.8 – Implement KPIs tables and nightly Celery job.

## Epic 2 – Goals & Priority Engine

**Goal:** Capture user goals, derive linked_txn_type, and priority_rank.

- Task 2.1 – Implement `goal_category_master` seed script.
- Task 2.2 – Implement life context API (`user_life_context`).
- Task 2.3 – Implement `/v1/goals/submit` endpoint.
- Task 2.4 – Implement priority scoring + ranking logic.
- Task 2.5 – Implement `/v1/goals` list/update/delete.
- Task 2.6 – React Goals UI with tabs (short/medium/long).

## Epic 3 – BudgetPilot Engine

- Task 3.1 – Seed `budget_plan_master` with templates.
- Task 3.2 – Implement `/v1/budget/recommendations` engine.
- Task 3.3 – Implement `/v1/budget/commit` + `user_budget_commit_goal_alloc`.
- Task 3.4 – Implement `budget_user_month_aggregate` variance computation.
- Task 3.5 – React BudgetPilot cards (3 plan options + explanation).

## Epic 4 – GoalCompass Tracking

- Task 4.1 – Implement `goal_contribution_fact` ETL job.
- Task 4.2 – Implement `goal_compass_snapshot` computation.
- Task 4.3 – Implement milestone detection (`user_goal_milestone_status`).
- Task 4.4 – Implement `/v1/goals/progress` & per-goal timeline API.
- Task 4.5 – React GoalCompass dashboard with progress bars and ETA.

## Epic 5 – MoneyMoments Nudge Engine

- Task 5.1 – Implement `mm_signal_daily` aggregation job.
- Task 5.2 – Implement rule evaluation (`mm_nudge_rule_master`).
- Task 5.3 – Implement templates (`mm_nudge_template_master`).
- Task 5.4 – Implement suppression + cooldown logic.
- Task 5.5 – Implement `/v1/moneymoments/feed` & settings APIs.
- Task 5.6 – React nudge feed and notification UI.

## Epic 6 – Realtime Email Ingestion (Gmail + Outlook)

- Task 6.1 – Implement Gmail OAuth + token storage.
- Task 6.2 – Implement Gmail watch (`/v1/gmail/watch/start`).
- Task 6.3 – Implement Gmail Pub/Sub webhook and history processing.
- Task 6.4 – Implement Outlook Graph subscription + webhook.
- Task 6.5 – Implement email parsers → `email_event` + `txn_staging`.
- Task 6.6 – Ensure dedupe and idempotency in ingestion.

## Epic 7 – SSE & Activity Feed

- Task 7.1 – Implement Redis-based pub/sub.
- Task 7.2 – Implement `/v1/events/stream` SSE endpoint.
- Task 7.3 – Implement `activity` table and logging pattern.
- Task 7.4 – Connect SpendSense/Goals/Budget/BudgetPilot/MoneyMoments events to SSE and activity.

## Epic 8 – Frontend PWA Shell

- Task 8.1 – Set up React + router + state management.
- Task 8.2 – Implement authentication flow (Supabase Auth).
- Task 8.3 – Implement base layout (sidebar, topbar, theming).
- Task 8.4 – Implement Dashboard overview (KPIs + cards).

Use these epics as the main roadmap for Augment and human engineers. Each task can be turned into an Augment job.
