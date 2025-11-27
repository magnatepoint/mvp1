---
type: "always_apply"
---

# 07_realtime_ingestion.md  
**Module:** Realtime Email Ingestion (Gmail + Outlook)  
**Version:** 1.0  
**Owner:** Backend Engineering / DevOps  
**Prepared by:** Monytix Team  

---

# 1. Objective

The Realtime Email Ingestion module enables **instant capture of financial transactions** from email alerts sent by:

- Banks  
- Credit cards  
- GPay/PhonePe  
- Mutual funds  
- Loans  
- Investment platforms  

The ingestion system must support **both Gmail & Outlook**, in realtime, with:

- Push-based delivery (Gmail Pub/Sub)  
- Poll-based fallback (Gmail History API)  
- Microsoft Graph webhooks for Outlook  
- Complete dedupe protection  
- Idempotent parsing  
- Rich event extraction  
- Realtime UI notifications via SSE  

---

# 2. Supported Email Providers

| Provider | Method | Realtime? | Notes |
|----------|--------|-----------|-------|
| **Gmail** | Pub/Sub push notifications + History API | Yes | Primary official method |
| **Outlook** | Microsoft Graph webhook subscription | Yes | Requires refresh subscription |
| **Fallback** | Manual pull (rare) | No | Debugging/testing only |

---

# 3. Data Flow Overview

## 3.1 Flow Diagram (End-to-End)
```
Incoming Email
     ↓
[Gmail → Pub/Sub push] OR [Outlook → Graph webhook]
     ↓
FastAPI → /v1/email/push/{provider}
     ↓
Store raw email payload (MongoDB: email_raw)
     ↓
Celery Task: parse_email_event()
     ↓
Extract financial event
     ↓
Persist canonical email event → email_event table
     ↓
Insert into txn_staging (Mongo)
     ↓
Celery Pipeline:
    normalize → categorize → enriched → vw_txn_effective
     ↓
Redis publish (SSE)
     ↓
React PWA Toast + UI refresh
```

---

# 4. Core Components

## 4.1 MongoDB Collections
- `email_raw` – Raw email JSON / MIME source  
- `email_parse_logs` – Parser logs and errors  
- `txn_staging` – Staging area for extracted events  

## 4.2 PostgreSQL Tables
- `gmail_state`  
- `outlook_state`  
- `email_ingest`  
- `email_event`  

See Data Dictionary module for full field definitions.

---

# 5. Gmail Ingestion (Primary Provider)

## FR-RT-1: Gmail Watch Setup

### Requirements:
- FR-RT-1.1: POST `/v1/gmail/watch/start` must:
  - Create/refresh Gmail watch using Gmail API
  - Store:
    - `history_id`
    - `watch_expires_at`
  - Schedule weekly refresh

### Response:

```json
{ "status": "watch_started" }
```

---

## FR-RT-2: Gmail Push Webhook (`/v1/gmail/push`)

This endpoint receives Pub/Sub push messages.

### Requirements:

- FR-RT-2.1: Validate Google-issued OIDC token  
- FR-RT-2.2: Extract `historyId` from message  
- FR-RT-2.3: Insert record into `email_ingest` with status="received"  
- FR-RT-2.4: Enqueue Celery task:
  ```
  process_gmail_history(user_id, history_id)
  ```

---

## FR-RT-3: Gmail History Processing

### Steps:

1. Fetch new messages since last `gmail_state.history_id`
2. For each message ID:
   - Fetch via Gmail API (`format=full`)
   - Store raw MIME in `email_raw`
   - Extract headers and snippet → update `email_ingest`
3. For each message:
   - Send raw content to parser engine

### Requirements:

- FR-RT-3.1: Must be idempotent (replays allowed)  
- FR-RT-3.2: Update gmail_state with latest historyId  
- FR-RT-3.3: Handle expiration (requires full resync)  

---

# 6. Outlook Ingestion

## FR-RT-4: Outlook Subscription

### Requirements:
- FR-RT-4.1: Use Microsoft Graph API:
  ```
  POST https://graph.microsoft.com/v1.0/subscriptions
  ```
- FR-RT-4.2: Subscribe to:
  ```
  message/created
  ```
- FR-RT-4.3: Store:
  - subscription_id  
  - expiration_date_time  

Refresh subscription every 24 hours.

---

## FR-RT-5: Outlook Push Webhook

`/v1/outlook/push`

### Requirements:
- Validate MS signature headers  
- Respond to validation handshake  
- Parse notification:
  ```
  { "value": [{ "resource": "/users/.../messages/{id}" }]}
  ```
- Fetch message via Graph API  
- Store raw email → `email_raw`  
- Create ingest record → `email_ingest`  
- Enqueue parser task

---

# 7. Email Parsing Engine

## FR-RT-6: Parser Contract

Parser must extract:

- provider (`hdfc_bank`, `icici_bank`, `sbi`, `axis`, `gpay`, `phonepe`, `amazon_pay`, `mf`, `loan`)  
- event_type:
  - `upi`
  - `card_debit`
  - `card_credit`
  - `atm_withdrawal`
  - `neft/rtgs/imps`
  - `salary_credit`
  - `loan_emi`
  - `fd_maturity`
  - `mf_buy`
  - `mf_redeem`
- amount  
- currency  
- posted_at  
- merchant  
- reference  
- account_hint (last4, VPA, card network)  
- raw_summary  

Example parser output:

```json
{
  "provider": "hdfc_bank",
  "event_type": "upi",
  "amount": -450.00,
  "merchant": "SWIGGY",
  "posted_at": "2025-10-23T11:20:00Z",
  "reference": "UPI/12345",
  "account_hint": "santoshmalla@oksbi"
}
```

---

## FR-RT-7: Error Handling

If parser fails:

- Write failure row in `email_parse_logs`
- Set status = "error" in `email_ingest`
- Flag for manual review (optional MVP)

---

# 8. Conversion to Staging Transactions

The email event must be stored in:

`email_event`

and also written to `txn_staging`:

```
{
  user_id,
  source_type: "email",
  raw_payload,
  parsed_fields,
  created_at
}
```

This triggers the SpendSense pipeline:

- normalize  
- categorize  
- aggregate  
- notify frontend  

---

# 9. Realtime User Notification (SSE)

## FR-RT-8: Redis Publish

After categorization completes:

```
publish("user:{user_id}", {
  "type": "transaction",
  "title": "New Transaction Detected",
  "body": "₹450 spent at Swiggy",
  "txn_id": "UUID"
})
```

## FR-RT-9: Frontend SSE Stream

Endpoint:

`GET /v1/events/stream?token=<JWT>`

Frontend receives:

- new transactions  
- nudges  
- goal updates  
- budget variances  

Latency target: **< 500ms**

---

# 10. Fallback Polling Logic

If Gmail push fails:

- Poll Gmail History API every 5 minutes  
- Compare `historyId` with stored value  
- Process deltas  

---

# 11. Security Requirements

- OAuth2 tokens stored encrypted  
- Gmail watch endpoints must require Google-issued OIDC tokens  
- Outlook webhooks must validate MS payload signatures  
- SSE must validate Supabase JWT before stream opens  
- All email content must be encrypted at rest  

---

# 12. Non-Functional Requirements

| Metric | Requirement |
|--------|-------------|
| Email → UI latency | < 2 seconds |
| Parser accuracy | ≥ 95% for supported banks/providers |
| Replay handling | Must remain fully idempotent |
| Monthly volume | 5,000 emails per user, scalable to 100k users |
| Safety | Never duplicate transactions |

---

# 13. Acceptance Criteria

- AC-RT-1: Gmail/Outlook email leads to transaction appearing in dashboard within 2 seconds  
- AC-RT-2: Duplicate emails must not create duplicate transactions  
- AC-RT-3: Parser must extract correct amount, merchant, timestamp  
- AC-RT-4: SSE notification must fire for each parsed event  
- AC-RT-5: Gmail watch refresh must not break ingestion  

---

# END OF MODULE 07 – Realtime Ingestion

Placeholder for full FRS content.
