---
type: "always_apply"
---

# 02_module.md

# 02_spendsense.md
**Module:** SpendSense – Transaction Engine & Categorization  
**Version:** 1.0  
**Owner:** Backend / Data Engineering  

---

## 1. Objective

SpendSense is responsible for turning raw financial events into a consistent, enriched transaction stream:

- Ingest transactions (CSV, email, manual)
- Normalize into canonical fact table
- Categorize using deterministic rules
- Allow user overrides without mutating canonical data
- Expose effective transaction view
- Feed KPI & downstream modules

---

## 2. Functional Requirements

### FR-SS-1: Ingest Transactions

**Sources:**

1. CSV/XLSX uploads (bank/card statements)  
2. Email events (Gmail / Outlook parsers)  
3. Manual transaction entry from UI  

**Requirements:**

- FR-SS-1.1: For each uploaded file, create an `upload_batch` record with:
  - `batch_id`, `user_id`, `source_type`, `file_name`, `total_rows`, `status`.
- FR-SS-1.2: Each row must be stored in `txn_staging` (Mongo) with:
  - `user_id`, `batch_id`, `raw_payload`, `parsed_fields`, `source_type`, `created_at`.
- FR-SS-1.3: In case of email ingestion, create a staging record with `source_type='email'` and reference to `email_event`.

**Preconditions:**

- User is authenticated (Supabase JWT)
- CSV/XLSX passes MIME + basic structure validation

**Postconditions:**

- All rows present in `txn_staging`
- Batch visible in batch listing API

---

### FR-SS-2: Normalize to Canonical Facts (`txn_fact`)

**Goal:** Convert each staging row into a canonical transaction.

**Fields:**

- `txn_id` (UUID)
- `user_id`
- `posted_at` (TIMESTAMPTZ)
- `amount` (NUMERIC), sign convention:
  - Income → positive
  - Expenses → negative
- `currency` (default `INR`)
- `raw_description`
- `source_type` (csv/email/manual)
- `merchant` (normalized)
- `account_hint` (VPA / last4 / IFSC / card network)
- `hash` (dedupe key)

**Requirements:**

- FR-SS-2.1: Implement a normalization job (`normalize_staging_to_fact`) that:
  - Reads unprocessed `txn_staging` rows
  - Derives canonical fields
  - Writes to `txn_fact`
- FR-SS-2.2: Compute hash as:
  ```text
  hash = sha256(user_id + posted_at + amount + currency + raw_description)
