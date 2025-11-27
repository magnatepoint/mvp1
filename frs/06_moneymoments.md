---
type: "always_apply"
---

# 06_moneymoments.md  
**Module:** MoneyMoments – Behavioral Nudging & Habit Formation Engine  
**Version:** 1.0  
**Owner:** Backend Engineering / Product Architecture  
**Prepared by:** Monytix Team  

---

# 1. Objective

MoneyMoments provides **contextual, rule-based behavioral nudges** based on:

- spending behavior (SpendSense KPIs)  
- budget variance (BudgetPilot)  
- goal underfunding (GoalCompass)  
- lifestyle patterns (dining/shopping/travel)  
- user traits (age, dependents, income type, region)  

It generates:

- actionable nudges  
- humorous & empathetic suggestions  
- daily/weekly behavior insights  
- app feed items  

MVP uses **pure rule logic**, no AI models.

---

# 2. Nudge System Overview

MoneyMoments operates in **4 stages**:

1. **Signal Generation**  
   Aggregate user behavior → `mm_signal_daily`
2. **Rule Evaluation**  
   Compare signals against rule expressions → create candidates
3. **Suppression & Throttling**  
   Respect user preferences & cooldown windows
4. **Nudge Delivery**  
   Store in `mm_nudge_delivery_log` & send via SSE to PWA

---

# 3. Data Inputs

## 3.1 SpendSense Inputs
- wants share  
- needs share  
- category-level totals (Dining, Shopping, Travel)  
- UPI peer payments  
- recurring merchants  
- spending leaks  

## 3.2 BudgetPilot Inputs
- variance_needs  
- variance_wants  
- variance_savings  
- monthly_commitment  

## 3.3 GoalCompass Inputs
- progress_pct  
- underfunding %  
- milestone achievements  

## 3.4 User Traits
Stored in `mm_user_traits`:

```
user_id
age_band
gender
lifestyle_tags (json)
region_code
```

---

# 4. Functional Requirements

## FR-MM-1: Daily Signal Aggregation (`mm_signal_daily`)

Run nightly Celery job:

```
compute_mm_daily_signals(user_id, date):
    dining_txn_7d
    shopping_txn_7d
    travel_txn_30d
    wants_share_30d
    savings_gap (planned - actual)
    underfunded_top_goal
    budget_variance
```

### Requirements:

- FR-MM-1.1: One record per user per day  
- FR-MM-1.2: Keep 90 days of signal history  
- FR-MM-1.3: Must complete in <15 minutes for 10k users

---

## FR-MM-2: Rule Evaluation Engine

Rules stored in:

```
mm_nudge_rule_master:
- rule_id
- name
- description
- expression_json
- cooldown_days
- traits_filter_json
- priority
```

### Rule Example:

Dining overspend:

```json
{
  "if": {
    "dining_txn_7d": { ">=": 3 },
    "wants_share_30d": { ">": 0.35 }
  },
  "message_template_id": "DINE_01"
}
```

### Requirements:

- FR-MM-2.1: Evaluate expressions using deterministic JSON rules  
- FR-MM-2.2: If rule matches → create entry in `mm_nudge_candidate`  
- FR-MM-2.3: Multiple rules may match; select highest priority  

---

## FR-MM-3: Nudge Template Master

Templates stored in:

`mm_nudge_template_master`

Fields:

```
template_id
title
body
tone        (e.g., humorous, empathetic, neutral)
variables_json
category    (dining/shopping/goal/budget)
```

Example body:

> “Looks tasty… but your **{goal_name}** fund is starving 😋”

---

## FR-MM-4: Suppression Layer

Stored in:

`mm_user_suppression`

### Requirements:

- FR-MM-4.1: Prevent more than 1 nudge / 24 hours per user  
- FR-MM-4.2: A rule with cooldown_days cannot trigger until cooldown expires  
- FR-MM-4.3: Users may mute categories (Dining, Shopping, Goals, Budget)

If suppressed:

- store suppression reason  
- skip candidate

---

## FR-MM-5: Nudge Delivery

Delivered nudges stored in:

`mm_nudge_delivery_log`

```
delivery_id (UUID)
user_id
title
body
category
meta_json
delivered_at
```

### Requirements:

- FR-MM-5.1: Delivery triggers both:
  - database log
  - realtime SSE event via Redis publish
- FR-MM-5.2: SSE must send:
```
{
  "type": "nudge",
  "title": "...",
  "body": "...",
  "category": "dining",
  "created_at": "timestamp"
}
```
- FR-MM-5.3: Frontend must show toast + place in feed

---

## FR-MM-6: User Interaction Logging

`mm_nudge_interaction_log` tracks:

```
interaction_id
delivery_id
user_id
action (viewed/clicked/dismissed)
timestamp
```

## FR-MM-6.1: Logged actions update:
- user responsiveness score  
- future rule targeting  

---

## FR-MM-7: Types of Nudges (MVP)

### 7.1 Dining Nudges
Triggered if:
- `dining_txn_7d >= 3`
- wants_share_30d > 0.35  

Example message:
> “Takeout again? 🍟  
> Your vacation fund is rolling its eyes.”

---

### 7.2 Shopping Nudges
Triggered if:
- shopping_txn_7d >= 2  
- month-on-month shopping up 20%  

---

### 7.3 Travel Nudges
Triggered if:
- travel_txn_30d > user baseline  
- upcoming yearly expenses are high  

---

### 7.4 Goal Underfunding Nudges
Triggered if:
- top priority goal progress < 10%  
- no actual savings this month  

---

### 7.5 Budget Variance Nudges
Triggered if:
- deviation from planned budget > 15%  

---

# 8. APIs

## 8.1 GET `/v1/moneymoments/feed`

Return list of all delivered nudges for the user.

Response example:

```json
{
  "feed": [
    {
      "id": "UUID",
      "title": "Oops! Dining spike detected",
      "body": "Looks tasty, but your Emergency Fund needs some love.",
      "category": "dining",
      "delivered_at": "2025-10-26T09:21:00Z"
    }
  ]
}
```

---

## 8.2 GET `/v1/moneymoments/settings`

Get suppression settings.

## 8.3 POST `/v1/moneymoments/settings`

Update mute preferences.

---

# 9. Non-Functional Requirements

- NFR-MM-1: Rule evaluation must run in <1 minute for 10k users  
- NFR-MM-2: SSE nudge delivery latency < 500ms  
- NFR-MM-3: No duplicate nudges for same rule within cooldown period  
- NFR-MM-4: All nudge messages must comply with neutral & helpful tone guidelines  

---

# 10. Acceptance Criteria

- AC-MM-1: No user receives more than 1 nudge in 24 hours  
- AC-MM-2: Rule matches generate exactly 1 candidate  
- AC-MM-3: Muted categories never generate nudges  
- AC-MM-4: SSE push contains correct data  
- AC-MM-5: Feed API ordered by delivered_at desc  

---

# END OF MODULE 06 – MoneyMoments
