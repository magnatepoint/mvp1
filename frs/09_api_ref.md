---
type: "always_apply"
---

# 09_api_reference.md
**Module:** API Reference (FastAPI)  
**Version:** 1.0  
**Owner:** Backend Engineering  
**Prepared by:** Monytix Team  

---

# 1. Overview

This API reference describes all backend endpoints necessary for the Monytix MVP, built on:

- FastAPI  
- PostgreSQL  
- MongoDB  
- Redis Pub/Sub (SSE events)
- Supabase Auth (JWT)

All endpoints must enforce:

```
Authorization: Bearer <JWT>
```

Unless marked `public`.

---

# 2. SpendSense API

## 2.1 Upload CSV/XLSX  
### POST `/v1/transactions/upload`
Upload a financial statement.

**Auth:** Required  
**Body:** `multipart/form-data`  

**Response:**
```json
{
  "batch_id": "UUID",
  "message": "Upload received. Processing started."
}
```

---

## 2.2 Check Batch Status  
### GET `/v1/transactions/upload/{batch_id}`

**Response:**
```json
{
  "batch_id": "UUID",
  "total_rows": 612,
  "processed": 598,
  "invalid": 14,
  "status": "completed"
}
```

---

## 2.3 List Transactions  
### GET `/v1/transactions?month=2025-10&category=Dining`

**Response (paginated):**
```json
{
  "items": [
    {
      "txn_id": "UUID",
      "posted_at": "2025-10-21T14:28:00Z",
      "amount": -450.0,
      "category": "Lifestyle",
      "subcategory": "Dining",
      "txn_type": "wants",
      "description": "SWIGGY UPI",
      "merchant": "SWIGGY"
    }
  ],
  "page": 1,
  "total": 128
}
```

---

## 2.4 Manual Transaction  
### POST `/v1/transactions/manual`

```json
{
  "posted_at": "2025-10-07T12:30:00Z",
  "amount": -500,
  "description": "Lunch at KFC"
}
```

**Response:** Effective enriched transaction.

---

## 2.5 Override Categorization  
### POST `/v1/transactions/override`

```json
{
  "txn_id": "UUID",
  "category": "Essentials",
  "subcategory": "Groceries",
  "txn_type": "needs"
}
```

**Response:**
```json
{ "status": "updated" }
```

---

# 3. Goals API

## 3.1 Submit Goals  
### POST `/v1/goals/submit`

```json
{
  "context": {
    "age_band": "25-34",
    "dependents": {"children": 1},
    "income_regularity": "stable"
  },
  "selected_goals": [
    {
      "goal_category": "Emergency",
      "goal_name": "Emergency Fund",
      "estimated_cost": 150000,
      "target_date": "2026-05-01",
      "importance": 5
    }
  ]
}
```

**Response:**
```json
{
  "goals_created": [
    { "goal_id": "UUID", "priority_rank": 1 }
  ]
}
```

---

## 3.2 Get All Goals  
### GET `/v1/goals`

---

## 3.3 Update Goal  
### PUT `/v1/goals/{goal_id}`

---

## 3.4 Delete Goal  
### DELETE `/v1/goals/{goal_id}`

Soft delete.

---

# 4. BudgetPilot API

## 4.1 Get Recommendations  
### GET `/v1/budget/recommendations`

**Response:**
```json
{
  "recommendations": [
    {
      "plan_code": "BAL_50_30_20",
      "needs_pct": 0.5,
      "wants_pct": 0.3,
      "savings_pct": 0.2,
      "reason": "Your spending profile is stable."
    }
  ]
}
```

---

## 4.2 Commit Budget  
### POST `/v1/budget/commit`

```json
{
  "plan_code": "BAL_50_30_20",
  "goal_allocations_json": {
    "UUID1": 8000,
    "UUID2": 4000
  }
}
```

---

## 4.3 Get User’s Committed Budget  
### GET `/v1/budget/commit`

---

# 5. GoalCompass API

## 5.1 Get Progress Overview  
### GET `/v1/goals/progress`

```json
{
  "goals": [
    {
      "goal_id": "UUID",
      "goal_name": "Emergency Fund",
      "progress_pct": 0.35,
      "remaining_amount": 97500,
      "projected_completion_date": "2027-11-01"
    }
  ]
}
```

---

## 5.2 Goal Timeline  
### GET `/v1/goals/{goal_id}/timeline`

---

# 6. MoneyMoments API

## 6.1 Get Nudge Feed  
### GET `/v1/moneymoments/feed`

```json
{
  "feed": [
    {
      "id": "UUID",
      "title": "Dining Spike Detected",
      "body": "Takeout again? Your Emergency Fund is crying.",
      "category": "dining"
    }
  ]
}
```

---

## 6.2 Get Settings  
### GET `/v1/moneymoments/settings`

---

## 6.3 Update Settings  
### POST `/v1/moneymoments/settings`

```json
{
  "muted_categories": ["dining", "shopping"]
}
```

---

# 7. Realtime Email Ingestion API

## 7.1 Gmail Watch Start  
### POST `/v1/gmail/watch/start`

---

## 7.2 Gmail Push Webhook  
### POST `/v1/gmail/push`  
**Public endpoint (Google only)**

---

## 7.3 Outlook Subscription  
### POST `/v1/outlook/subscribe`

---

## 7.4 Outlook Push Webhook  
### POST `/v1/outlook/push`  
**Public endpoint (MS Graph only)**

---

# 8. SSE Event Stream

## GET `/v1/events/stream`

Client receives:

```json
{
  "type": "transaction",
  "title": "New Transaction",
  "body": "₹450 spent at Swiggy",
  "txn_id": "UUID"
}
```

Or:

```json
{ "type": "nudge", ... }
```

Or:

```json
{ "type": "goal_update", ... }
```

---

# 9. Authentication

## 9.1 Login  
### POST `/auth/login`  
(Supabase handles JWT, backend verifies)

## 9.2 Verify session  
### GET `/auth/session`

---

# 10. Utility APIs

### GET `/v1/health`
Returns OK + queue worker status.

### GET `/v1/version`
Returns commit hash and build version.

---

# 11. Error Response Standard

All errors follow:

```json
{
  "error": {
    "code": "INVALID_INPUT",
    "message": "Category not found."
  }
}
```

Common codes:  
- INVALID_INPUT  
- NOT_FOUND  
- UNAUTHORIZED  
- RATE_LIMITED  
- SERVER_ERROR  

---

# END OF MODULE 09 – API Reference
