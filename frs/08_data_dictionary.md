---
type: "always_apply"
---

# 08_data_dictionary.md  
**Module:** Data Dictionary (PostgreSQL + MongoDB)  
**Version:** 1.0  
**Prepared by:** Monytix Team  

---

# 1. Overview

This module defines **all database schemas** used by:

- SpendSense  
- Goals  
- BudgetPilot  
- GoalCompass  
- MoneyMoments  
- Realtime Ingestion  
- Activity Feed  
- SSE Notifications  

Includes:

- field-level meaning  
- constraints  
- indexes  
- relationships  
- data lineage notes  

---

# 2. PostgreSQL Tables

## 2.1 `txn_fact` — Canonical Transaction Table

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| txn_id | UUID | primary key | PK |
| user_id | TEXT | Supabase user id | NOT NULL |
| posted_at | TIMESTAMPTZ | Event timestamp | NOT NULL |
| amount | NUMERIC(14,2) | Amount in INR, signed | NOT NULL |
| currency | VARCHAR(8) | Default 'INR' | DEFAULT |
| raw_description | TEXT | Original description |  |
| merchant | TEXT | Normalized merchant |  |
| account_hint | TEXT | last4, VPA, IFSC, card network |  |
| source_type | TEXT | csv/email/manual |  |
| hash | CHAR(64) | dedupe key | UNIQUE |
| created_at | TIMESTAMPTZ | ingestion time | DEFAULT now() |

### Indexes:
```
idx_txn_fact_user_id
idx_txn_fact_user_date
idx_txn_fact_hash_unique
```

---

## 2.2 `txn_enriched` — Categorization Layer

| Column | Type | Description |
|--------|------|-------------|
| txn_id | UUID PK | references txn_fact |
| category | TEXT | e.g., Lifestyle |
| subcategory | TEXT | e.g., Dining |
| txn_type | TEXT | needs/wants/assets/income/transfers |
| rule_applied | TEXT | rule id or description |
| confidence | NUMERIC(3,2) | 0–1 |
| enriched_at | TIMESTAMPTZ | timestamp |

---

## 2.3 `txn_override` — User Category Overrides

| Column | Type |
|--------|------|
| txn_id | UUID PK |
| user_id | TEXT |
| category | TEXT |
| subcategory | TEXT |
| txn_type | TEXT |
| overridden_at | TIMESTAMPTZ DEFAULT now() |

---

## 2.4 `vw_txn_effective` — Effective Transaction View

### Final enriched transaction exposed to UI.

Fields:

- from `txn_fact`
- overlapped with override or enriched result

```
category = COALESCE(override.category, enriched.category)
...
```

Not a physical table; defined as a VIEW.

---

# 3. Staging & Raw (MongoDB)

## 3.1 `txn_staging` — Raw parsed transactions

```
{
  _id: ObjectId,
  user_id: string,
  batch_id: string,
  raw_payload: object,
  parsed_fields: object,
  source_type: "csv" | "email" | "manual",
  created_at: ISODate
}
```

## 3.2 `email_raw` — Raw email content

```
{
  _id: ObjectId,
  user_id: string,
  provider: "gmail" | "outlook",
  message_id: string,
  thread_id: string,
  raw_mime: string,
  headers: object,
  snippet: string,
  received_at: ISODate
}
```

## 3.3 `email_parse_logs`

```
{
  _id,
  message_id,
  parser_version,
  status: "success" | "error",
  error_message,
  parsed_fields,
  created_at
}
```

---

# 4. Realtime Ingestion Tables (PostgreSQL)

## 4.1 `gmail_state`

| Column | Type |
|--------|------|
| user_id | TEXT PK |
| history_id | BIGINT |
| watch_expires_at | TIMESTAMPTZ |
| created_at | TIMESTAMPTZ |
| updated_at | TIMESTAMPTZ |

---

## 4.2 `outlook_state`

Similar structure to gmail_state:

| Column | Type |
|--------|------|
| user_id | TEXT PK |
| subscription_id | TEXT |
| expires_at | TIMESTAMPTZ |
| created_at | TIMESTAMPTZ |
| updated_at | TIMESTAMPTZ |

---

## 4.3 `email_ingest`

| Column | Type |
|--------|------|
| message_id | TEXT PK |
| user_id | TEXT |
| thread_id | TEXT |
| from_addr | TEXT |
| subject | TEXT |
| snippet_sha | CHAR(64) |
| status | TEXT | received/parsed/error |
| error_message | TEXT |
| created_at | TIMESTAMPTZ |

---

## 4.4 `email_event`

| Column | Type |
|--------|------|
| email_event_id | UUID PK |
| user_id | TEXT |
| message_id | TEXT |
| provider | TEXT |
| event_type | TEXT | upi/card_debit/salary/mf_buy/... |
| posted_at | TIMESTAMPTZ |
| amount | NUMERIC(14,2) |
| currency | TEXT |
| merchant | TEXT |
| reference | TEXT |
| account_hint | TEXT |
| raw_summary | TEXT |
| created_at | TIMESTAMPTZ |

---

# 5. Goals Module Tables

## 5.1 `goal_category_master`

| Column | Type |
|--------|------|
| goal_category | VARCHAR(50) |
| goal_name | VARCHAR(80) |
| default_horizon | VARCHAR(16) |
| policy_linked_txn_type | VARCHAR(12) |
| is_mandatory_flag | BOOLEAN |
| suggested_min_amount_formula | TEXT |
| display_order | SMALLINT |

---

## 5.2 `user_goals_master`

| Column | Type |
|--------|------|
| goal_id | UUID PK |
| user_id | TEXT |
| goal_category | TEXT |
| goal_name | TEXT |
| goal_type | TEXT | short/medium/long |
| linked_txn_type | TEXT |
| estimated_cost | NUMERIC(14,2) |
| target_date | DATE |
| current_savings | NUMERIC(14,2) |
| priority_rank | SMALLINT |
| status | TEXT | active/completed/archived |
| notes | TEXT |
| created_at | TIMESTAMPTZ |

Index: `idx_user_goals_user`

---

# 6. BudgetPilot Tables

## 6.1 `budget_plan_master`

| Column | Type |
|--------|------|
| plan_code | TEXT PK |
| plan_name | TEXT |
| needs_pct | NUMERIC |
| wants_pct | NUMERIC |
| savings_pct | NUMERIC |
| description | TEXT |
| eligibility_rules_json | JSONB |
| display_order | SMALLINT |

---

## 6.2 `user_budget_recommendation`

| Column | Type |
|--------|------|
| user_id | TEXT |
| plan_code | TEXT |
| needs_budget_pct | NUMERIC |
| wants_budget_pct | NUMERIC |
| savings_budget_pct | NUMERIC |
| recommendation_reason | TEXT |
| created_at | TIMESTAMPTZ |

---

## 6.3 `user_budget_commit`

| Column | Type |
|--------|------|
| user_id | TEXT |
| plan_code | TEXT |
| committed_at | TIMESTAMPTZ |
| goal_allocations_json | JSONB |

---

## 6.4 `user_budget_commit_goal_alloc`

| Column | Type |
|--------|------|
| user_id | TEXT |
| goal_id | UUID |
| monthly_amount | NUMERIC(14,2) |
| plan_code | TEXT |
| month | DATE |

---

## 6.5 `budget_user_month_aggregate`

| Column | Type |
|--------|------|
| user_id | TEXT |
| month | DATE |
| planned_needs | NUMERIC |
| planned_wants | NUMERIC |
| planned_savings | NUMERIC |
| actual_needs | NUMERIC |
| actual_wants | NUMERIC |
| actual_savings | NUMERIC |
| variance_needs | NUMERIC |
| variance_wants | NUMERIC |
| variance_savings | NUMERIC |

---

# 7. GoalCompass Tables

## 7.1 `goal_contribution_fact`

| Column | Type |
|--------|------|
| user_id | TEXT |
| month | DATE |
| goal_id | UUID |
| planned_amount | NUMERIC |
| actual_amount | NUMERIC |
| created_at | TIMESTAMPTZ |

---

## 7.2 `goal_compass_snapshot`

| Column | Type |
|--------|------|
| user_id | TEXT |
| month | DATE |
| goal_id | UUID |
| progress_pct | NUMERIC(5,2) |
| current_savings_open | NUMERIC |
| current_savings_close | NUMERIC |
| remaining_amount | NUMERIC |
| projected_completion_date | DATE |

---

## 7.3 `user_goal_milestone_status`

| Column | Type |
|--------|------|
| user_id | TEXT |
| goal_id | UUID |
| milestone_pct | INT | 25/50/75/100 |
| attained_at | DATE |

---

# 8. MoneyMoments Tables

## 8.1 `mm_signal_daily`

| Column | Type |
|--------|------|
| user_id | TEXT |
| date | DATE |
| dining_txn_7d | INT |
| shopping_txn_7d | INT |
| travel_txn_30d | INT |
| wants_share_30d | NUMERIC |
| savings_gap | NUMERIC |
| underfunded_top_goal | BOOLEAN |
| budget_variance | NUMERIC |
| created_at | TIMESTAMPTZ |

---

## 8.2 `mm_nudge_rule_master`

Defines rule conditions.

```
rule_id PK
name
description
expression_json
cooldown_days
traits_filter_json
priority
created_at
```

---

## 8.3 `mm_nudge_template_master`

```
template_id PK
title
body
tone
variables_json
category
created_at
```

---

## 8.4 `mm_nudge_candidate`

```
candidate_id PK
user_id
rule_id
evaluated_at
reason_json
```

---

## 8.5 `mm_user_suppression`

```
user_id PK
muted_categories jsonb
cooldown_until timestamptz
```

---

## 8.6 `mm_nudge_delivery_log`

```
delivery_id PK
user_id
rule_id
title
body
category
meta_json
delivered_at
```

---

## 8.7 `mm_nudge_interaction_log`

```
interaction_id PK
delivery_id
user_id
action
timestamp
```

---

# 9. Activity Feed Table

## 9.1 `activity`

```
activity_id UUID PK
user_id TEXT
kind TEXT
title TEXT
body TEXT
meta JSONB
created_at TIMESTAMPTZ
read_at TIMESTAMPTZ
```

---

# 10. SSE / Notification System (Redis)

### Channels:
- `user:{user_id}`  
- `admin:{admin_id}` (future)

### Message envelope:

```
{
  "type": "transaction" | "nudge" | "goal" | "budget" | "info",
  "title": "...",
  "body": "...",
  "meta": { ... },
  "created_at": "timestamp"
}
```

---

# 11. Constraints Summary

- Use UUID for all PKs  
- Use `TIMESTAMPTZ` for all timestamps  
- Set all foreign key references to ON DELETE CASCADE (unless user_id)  
- JSONB for flexible fields  
- Ensure all financial amounts are NUMERIC(14,2)  

---

# END OF MODULE 08 – Data Dictionary

