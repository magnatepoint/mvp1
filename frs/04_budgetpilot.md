---
type: "always_apply"
---

# 04_budgetpilot.md  
**Module:** BudgetPilot – Automated Budget Recommendation Engine  
**Version:** 1.0  
**Owner:** Backend Engineering / Product Architecture  
**Prepared by:** Monytix Team  

---

# 1. Objective

BudgetPilot transforms a user’s:

- categorized transactions (SpendSense)  
- declared financial goals (Goals module)  
- priority ranks  
- savings patterns  
- income stability and life context  

…into **automated monthly budget recommendations**.

This is a **rule-based budgeting engine** (non-AI) that outputs:

- 3 tailored budget plan recommendations  
- each with needs/wants/assets allocation  
- plus a reason for recommendation  
- plus goal-level allocation suggestions  

BudgetPilot then records user commitment and exposes tracking signals for GoalCompass and MoneyMoments.

---

# 2. Functional Requirements

## FR-BP-1: Inputs

BudgetPilot requires the following data inputs:

| Source | Data |
|--------|------|
| SpendSense | income, needs, wants, assets totals per month |
| Goals module | user_goals_master with priority_rank |
| Life Context | age_band, dependents, employment, region_code |
| Dim tables | goal_category_master, budget_plan_master |

### Input Constraints:

- Must use latest `vw_txn_effective` month summary.
- At least one active goal required for goal-based plans.

---

## FR-BP-2: Budget Template Registry (`budget_plan_master`)

The system must maintain an extensible catalog of budget templates.

### Fields:

```
budget_plan_master:
- plan_code (PK)
- plan_name
- needs_pct
- wants_pct
- savings_pct
- description
- eligibility_rules_json
- display_order
```

### Predefined Templates (MVP):

1. **Balanced Plan (50/30/20)**  
2. **Emergency Priority Plan**  
3. **Debt-First Plan**  
4. **Goal-Priority Plan**

**FR-BP-2.1:** Must support extensions (new templates).

**FR-BP-2.2:** Templates must define eligibility conditions such as:

- user has debt-related goals  
- user has <3 months emergency fund  
- wants % of income > 40%  
- income irregularity = high  

---

## FR-BP-3: Recommendation Engine

### Process Overview:

1. Fetch last 3 months avg income and spending pattern  
2. Fetch active goals ordered by priority_rank  
3. Evaluate template eligibility  
4. Compute personalized allocations  
5. Generate 3 recommended plans  
6. Store under `user_budget_recommendation`

---

### FR-BP-3.1: Needs, Wants, Savings Baseline

Using `vw_txn_effective`:

```
needs_ratio = needs_total / income_total
wants_ratio = wants_total / income_total
savings_ratio = assets_total / income_total (positive inflows)
```

If income_total < 0 → default fallback template only.

---

### FR-BP-3.2: Select 3 Best Templates

Rules:

- If user has high-priority emergency goal → include emergency template  
- If user has debt-related goals → include debt-first template  
- Always include balanced plan  
- If wants% > 40% → include wants-control variant  
- If user has 3+ active goals → include goal-priority template  

---

### FR-BP-3.3: Personalized Allocation

BudgetPilot must derive:

```
monthly_income = avg(income_last_3m)

needs_budget = monthly_income * needs_pct
wants_budget = monthly_income * wants_pct
savings_budget = monthly_income * savings_pct
```

### FR-BP-3.4: Goal Allocation Expansion

`savings_budget` must then be allocated across user goals based on:

- priority_rank (higher → more allocation)
- goal urgency (target_date soon → more allocation)
- goal estimated_cost vs current_savings (funding gap)

Algorithm:

```
weight_i = priority_weight + urgency_weight + gap_weight
goal_i_alloc = (weight_i / sum(weights)) * savings_budget
```

Store result in:

`user_budget_commit_goal_alloc` (after user commits a plan)

---

## FR-BP-4: API Specifications

### 4.1 GET `/v1/budget/recommendations`

**Returns:**  
- list of 3 recommended plans  
- each plan contains:  
  - plan_code  
  - needs_pct  
  - wants_pct  
  - savings_pct  
  - recommendation_reason  
  - preview: ranked goal allocation JSON  

Example Response:

```json
{
  "recommendations": [
    {
      "plan_code": "BAL_50_30_20",
      "needs_pct": 0.5,
      "wants_pct": 0.3,
      "savings_pct": 0.2,
      "reason": "Your wants spending is stable and income pattern predictable.",
      "goal_preview": [
        { "goal_id": "UUID1", "allocation_pct": 0.6 },
        { "goal_id": "UUID2", "allocation_pct": 0.4 }
      ]
    }
  ]
}
```

---

### 4.2 POST `/v1/budget/commit`

**Body:**

```json
{
  "plan_code": "BAL_50_30_20",
  "goal_allocations_json": {
    "UUID1": 9000,
    "UUID2": 6000
  }
}
```

**Behavior:**

1. Validate plan exists  
2. Validate allocations sum = savings_budget  
3. Write to `user_budget_commit`  
4. Expand into `user_budget_commit_goal_alloc`  

---

### 4.3 GET `/v1/budget/commit`

Returns latest user commitment.

---

## FR-BP-5: Monitoring & Variance

### FR-BP-5.1 Compute Actual vs Planned

Monthly job `compute_budget_variance`:

```
actual_needs = sum(needs from vw_txn_effective)
actual_wants = sum(wants)
actual_savings = sum(assets)
variance_needs = actual_needs - planned_needs
...
```

Store in:

`budget_user_month_aggregate`

### FR-BP-5.2: Expose Variances for GoalCompass & MoneyMoments

---

## 6. Data Structures

### 6.1 `user_budget_recommendation`

```
user_id
plan_code
needs_budget_pct
wants_budget_pct
savings_budget_pct
recommendation_reason
created_at
```

### 6.2 `user_budget_commit`

```
user_id
plan_code
committed_at
goal_allocations_json (jsonb)
```

### 6.3 `user_budget_commit_goal_alloc`

```
user_id
goal_id
monthly_amount
plan_code
month
```

---

## 7. Acceptance Criteria

- AC-BP-1: Recommendation request returns exactly 3 plans  
- AC-BP-2: Budget allocation sums = monthly income  
- AC-BP-3: Goal weights reflect priority rank correctly  
- AC-BP-4: Committing a plan writes 2 layer persistence:
  - commit record
  - goal allocations table  
- AC-BP-5: Variance <= 500ms query latency  

---

# END OF MODULE 04 – BudgetPilot
