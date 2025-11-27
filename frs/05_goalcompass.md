---
type: "always_apply"
---

# 05_goalcompass.md  
**Module:** GoalCompass – Goal Tracking & Progress Visualization  
**Version:** 1.0  
**Owner:** Backend / Data Engineering  
**Prepared by:** Monytix Team  

---

# 1. Objective

GoalCompass converts:

- user goals (`user_goals_master`),  
- user budget commitments (`user_budget_commit`),  
- savings contributions (`vw_txn_effective` txn_type=assets),  

into:

- per-goal contribution records  
- cumulative savings progress  
- monthly snapshots  
- milestone attainment  
- estimated completion date (ETA)  

GoalCompass is a **tracking engine**, not a planning engine.  
It updates *monthly* by default (daily optional for future versions).

---

# 2. Key Entities

GoalCompass works primarily with these tables:

- `user_goals_master` — user’s goals  
- `user_budget_commit_goal_alloc` — planned monthly allocations per goal  
- `vw_txn_effective` — actual transaction contributions  
- `goal_contribution_fact` — actual + planned per-goal contributions  
- `goal_compass_snapshot` — cumulative progress  
- `user_goal_milestone_status` — milestone achievements (25/50/75/100%)

These are fully covered in “Data Dictionary” module; this document specifies functional behavior.

---

# 3. Functional Requirements

## FR-GC-1: Planned Goal Allocation Expansion

After the user commits a budget:

### Inputs:
```
user_budget_commit
user_budget_commit_goal_alloc
```

BudgetPilot expands savings_budget → goal-level per-month allocations.

### Requirements:

- FR-GC-1.1: For each active goal:
  - compute its `planned_amount` for the month
- FR-GC-1.2: Planned amounts must remain constant throughout the month
- FR-GC-1.3: Only active goals (status=active) receive allocations

### Acceptance:
- Sum(goal_i planned) = user’s `savings_budget`  
- Archived/Completed goals receive zero planned allocation  

---

## FR-GC-2: Actual Savings Attribution

Actual savings come from SpendSense:

```
txn_type = 'assets'
amount < 0 (investment outflows)
```

### Requirements:

- FR-GC-2.1: For each month:
  - compute total actual savings = sum(asset transactions)
- FR-GC-2.2: Attribute actual savings **pro-rata** across goals using weights:

```
goal_weight_i = planned_amount_i
actual_alloc_i = (planned_amount_i / sum(planned)) * actual_total
```

### FR-GC-2.3: In absence of planned budgets (no commit):
- Use fallback equal distribution across goals
- Or assign 100% to highest priority goal (configurable, choose equal for MVP)

### Acceptance:
- Sum(actual_alloc_i) = actual_total ± rounding errors  
- No attribution to goals with zero planned cycles (unless fallback applied)

---

## FR-GC-3: Contribution Fact Table

Store planned & actual contributions:

```
goal_contribution_fact:
- user_id
- month
- goal_id
- planned_amount
- actual_amount
- created_at
```

### Requirements:

- FR-GC-3.1: One row per (user_id, month, goal_id)
- FR-GC-3.2: Re-running job for same period must upsert, not duplicate
- FR-GC-3.3: If a goal becomes archived → planned=0, actual calculated from past only

---

## FR-GC-4: Cumulative Progress Snapshot

Compute cumulative savings at month end:

```
current_savings_open  = sum(actual up to previous month)
current_savings_close = current_savings_open + actual_amount_this_month
progress_pct = current_savings_close / estimated_cost
remaining_amount = estimated_cost - current_savings_close
```

### Requirements:

- FR-GC-4.1: Write snapshot into `goal_compass_snapshot`:
```
user_id
month
goal_id
progress_pct
current_savings_open
current_savings_close
remaining_amount
projected_completion_date
```

- FR-GC-4.2: `projected_completion_date`:
  - If `actual_amount_this_month <= 0`: null (insufficient data)
  - Else:
    ```
    months_remaining = remaining_amount / actual_amount_this_month
    projected_completion_date = today + months_remaining months
    ```

### Acceptance:
- For completed goals: projected date = current month  
- For zero actual contributions: projected date = null  

---

## FR-GC-5: Milestones

Milestones are thresholds: **25%, 50%, 75%, and 100%**

### Requirements:

- FR-GC-5.1: For each goal:
  - When progress_pct crosses a milestone → create record:

```
user_goal_milestone_status:
- user_id
- goal_id
- milestone_pct
- attained_at
```

- FR-GC-5.2: Must not create duplicate milestone rows

### Acceptance:
- Marking 50% once must not be repeated next month  
- 100% marks goal as complete automatically  

---

## FR-GC-6: Goal Completion Logic

### Rules:

- When `progress_pct >= 100%`:
  - mark goal status → `completed`
  - future planned contributions → 0
  - actual contributions → still counted

---

# 4. APIs

## 4.1 GET `/v1/goals/progress`

Returns latest snapshot for all active goals.

**Response Example:**

```json
{
  "goals": [
    {
      "goal_id": "UUID",
      "goal_name": "Emergency Fund",
      "progress_pct": 0.35,
      "current_savings_close": 52500,
      "remaining_amount": 97500,
      "projected_completion_date": "2027-11-01",
      "milestones": [25]
    }
  ]
}
```

---

## 4.2 GET `/v1/goals/{goal_id}/timeline`

Returns:

- monthly contribution history
- milestone achievements

---

# 5. Non-Functional Requirements

- NFR-GC-1: Monthly job must complete in < 10 minutes for 10,000 users  
- NFR-GC-2: Snapshot queries must return < 300ms  
- NFR-GC-3: All computations must be idempotent  
- NFR-GC-4: Cumulative savings must strictly equal sum of actuals across history  

---

# 6. Data Quality Rules

- Goal with `estimated_cost = 0` → invalid  
- current_savings cannot exceed estimated_cost unless completed  
- actual_amount negative values only (investment outflows)  

---

# 7. Error Conditions

| Condition | System Behavior |
|----------|-----------------|
| No budget commit | fallback attribution rule |
| Zero actual savings | projected_date = null |
| Goal archived | skip future allocations |
| Goal deleted | do not remove past data |

---

# END OF MODULE 05 – GoalCompass

