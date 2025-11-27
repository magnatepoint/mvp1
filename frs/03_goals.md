---
type: "always_apply"
---

# 03_goals.md  
**Module:** Goals (Goal Capture, Prioritization, Category Linking)  
**Version:** 1.0  
**Owner:** Backend Engineering / Product Architecture  
**Prepared by:** Monytix Team  

---

# 1. Objective

The **Goals Module** allows users to:

- Capture short-, medium-, and long-term financial goals  
- Auto-classify goals using a catalog (`goal_category_master`)  
- Auto-derive `linked_txn_type` (needs/wants/assets)  
- Compute **priority scores** for each goal  
- Assign a **priority rank** (1 = top priority)  
- Persist user-specific goals in `user_goals_master`  
- Provide downstream inputs to BudgetPilot and GoalCompass  

This is a *deterministic*, rules-based module.

---

# 2. Functional Requirements

## FR-GO-1: Life Context Capture

On first launch of the Goals module, user must provide:

| Field | Description | Examples |
|-------|-------------|----------|
| age_band | Age range | 25–34 |
| dependents | Dictionary | children count, parents care |
| employment | salaried / self-employed | salaried |
| income_regularity | very_stable / stable / variable | stable |
| region_code | For cost-of-living hints | IN-KA |

**Requirements:**

- FR-GO-1.1: Validate against enumerated LOVs  
- FR-GO-1.2: Store in `user_life_context` table  
- FR-GO-1.3: Use context to pre-select/highlight recommended goals  

**Acceptance:**

- User cannot proceed without completing context  
- Subsequent updates allowed (PUT endpoint)

---

## FR-GO-2: Goal Catalog (Static Master)

The system must expose a **goal catalog** grouped by horizon:

- short-term (0–2y)  
- medium-term (2–5y)  
- long-term (5y+)  

The catalog comes from `goal_category_master`.

### Fields (functional spec):

| Field | Description |
|--------|-------------|
| goal_category | e.g., Emergency, Healthcare, Retirement |
| goal_name | e.g., Emergency Fund |
| default_horizon | short/medium/long |
| policy_linked_txn_type | needs/wants/assets |
| is_mandatory_flag | TRUE for essential goals |
| display_order | ordering in UI |
| suggested_min_amount_formula | optional rule hint (e.g. 3–6× monthly needs) |

**FR-GO-2.1:** A GET endpoint must return this catalog to the frontend.  
**FR-GO-2.2:** Unique constraint on `(goal_category, goal_name)`.  

---

## FR-GO-3: Goal Selection Workflow

User selects one or more items from catalog.

Flow:

1. User browses catalog by horizon  
2. User selects any number of goals  
3. For each selected goal → open “Goal Detail Form”

**FR-GO-3.1:** Must support selecting multiple goals at once.  
**FR-GO-3.2:** Must support adding a **custom goal** with free-text name.  
**FR-GO-3.3:** Custom goal must map to a `goal_category="Custom"`.

---

## FR-GO-4: Goal Detail Form

For each chosen goal, user must input:

| Field | Required | Notes |
|--------|----------|--------|
| estimated_cost | Yes | Target INR amount |
| target_date | Yes (unless horizon is chosen) | Must be in future |
| current_savings | Optional | INR amount |
| importance | Yes | Slider 1–5 |
| notes | Optional | Free text |

**Rules:**

- FR-GO-4.1: If target_date missing → derive using horizon:
  - short_term → +1 year
  - medium_term → +3 years
  - long_term → +7 years
- FR-GO-4.2: Validate `estimated_cost > 0`
- FR-GO-4.3: If `current_savings > estimated_cost`, mark goal as “completed”

---

## FR-GO-5: Linked Transaction Type Derivation (`linked_txn_type`)

System must auto-assign which transaction type contributes to goal.

Mapping (policy from `goal_category_master`):

- assets → savings/investments goals (e.g., Emergency Fund, Retirement)
- needs → protection/insurance goals
- wants → lifestyle goals (travel, gadgets, upgrades)

**Rules:**

- FR-GO-5.1: Use catalog default unless user overrides  
- FR-GO-5.2: Some categories allow override (Travel, Gadgets)  
- FR-GO-5.3: Persist final value in `user_goals_master`

---

## FR-GO-6: Priority Score Calculation

Each goal must receive a **priority score (0–100)** based on:

### Inputs:

| Factor | Weight | Rule |
|--------|--------|------|
| Safety/Protection | 30% | if `is_mandatory_flag` = true → +30 |
| Liability Pressure | 20% | if goal is debt-related |
| Time Urgency | 20% | closer the `target_date`, higher the score |
| Dependency Needs | 15% | if user has dependents relevant to goal |
| User Importance | 15% | slider (1–5) → score 0–15 |

### Formula (sample):

```
priority_score =
   safety_component
 + liability_component
 + urgency_component
 + dependency_component
 + user_component
```

### Priority Ranking:

After computing scores:

- FR-GO-6.1: Sort descending → assign `priority_rank` (1, 2, 3…)  
- FR-GO-6.2: Ties broken by earliest `target_date`  
- FR-GO-6.3: Highlight top 3 goals to user  

**Acceptance:**

- Emergency Fund should almost always be rank 1 if not completed
- Updating any goal must recompute all ranks

---

## FR-GO-7: Persistence (user_goals_master)

The backend must write user goals to:

```
user_goals_master
- goal_id (UUID)
- user_id
- goal_category
- goal_name
- goal_type (short/medium/long)
- linked_txn_type (derived)
- estimated_cost
- target_date
- current_savings
- priority_rank
- status (active/completed/deferred)
- notes
- created_at
```

**FR-GO-7.1:** Upsert user goals.  
**FR-GO-7.2:** Automatically mark status=completed if `current_savings >= estimated_cost`.  
**FR-GO-7.3:** Deleting a goal sets status=archived (soft delete).

---

## FR-GO-8: API Specifications

### POST `/v1/goals/submit`

**Request:**

```json
{
  "context": {
    "age_band": "25-34",
    "dependents": { "children": 1, "parents_care": true },
    "employment": "salaried",
    "income_regularity": "stable",
    "region_code": "IN-TG"
  },
  "selected_goals": [
    {
      "goal_category": "Emergency",
      "goal_name": "Emergency Fund",
      "estimated_cost": 150000,
      "target_date": "2026-05-01",
      "current_savings": 20000,
      "importance": 5
    }
  ]
}
```

**Response:**

```json
{
  "goals_created": [
    {
      "goal_id": "UUID",
      "priority_rank": 1
    }
  ]
}
```

---

### GET `/v1/goals`

Returns all active user goals ordered by priority rank.

### PUT `/v1/goals/{goal_id}`

Update cost, date, savings, or notes.

### DELETE `/v1/goals/{goal_id}`

Soft delete.

---

## 9. Non-functional Requirements

- NFR-GO-1: Rank recalculation < 200ms  
- NFR-GO-2: Catalog must load < 100ms  
- NFR-GO-3: All goal operations must be fully auditable  

---

# END OF MODULE 03 – Goals
