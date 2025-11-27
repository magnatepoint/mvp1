---
type: "always_apply"
---

# Monytix Functional Requirements Specification (FRS)
# 01_introduction_architecture.md  
**Document Version:** 1.0  
**System:** Monytix MVP  
**Module:** Introduction & Architecture  
**Owner:** Business Architecture / Engineering Architecture  
**Prepared by:** Monytix Founding Team  
**Last Updated:** {{DATE}}

---

# 1.0 Purpose of This Document
The purpose of the Functional Requirements Specification (FRS) is to define the *complete, implementation-ready* behavior of the **Monytix MVP** platform.  

This document is written to support:

- Backend engineers (FastAPI, Celery, PostgreSQL)  
- Frontend engineers (React PWA)  
- Data engineers (ETL, KPI jobs)  
- DevOps (Supabase, Redis, infra)  
- QA engineers  
- AI automation assistants (Augment AI agents)  
- Founders and product owners  

Every module in the system — SpendSense, Goals, BudgetPilot, GoalCompass, MoneyMoments, and Realtime Ingestion — is fully defined here in functional, technical, and data terms.

This FRS is **implementation-driven**, meaning engineers should be able to build the product end-to-end without ambiguity.

---

# 2.0 Product Overview

Monytix is a **next-generation personal finance platform** for the Indian market that ingests financial data via:

- realtime email alerts (Gmail + Outlook)  
- CSV/XLSX bank statements  
- manual entry  
- future SMS ingestion  

The system then:

1. Parses and normalizes all financial events  
2. Categorizes and enriches them  
3. Computes behavior, insights, and KPIs  
4. Generates budgets, goals, and nudges  
5. Sends realtime UI updates via SSE  

The MVP is **non-AI**, rule-based, deterministic, and fully auditable.

---

# 3.0 System Scope

This FRS covers all modules required for the MVP:

| Module | Description |
|--------|-------------|
| SpendSense | Transaction ingestion + categorization + KPIs |
| Goals | Goal capture, prioritization, linkage |
| BudgetPilot | Automated budget recommendations |
| GoalCompass | Goal tracking, progress, ETA |
| MoneyMoments | Behavioral nudges |
| Realtime Ingestion | Gmail (Pub/Sub), Outlook (Graph API) |
| Frontend PWA | Dashboards, goals, budgets, transactions |
| Data Layer | PostgreSQL + MongoDB |
| Infra | Supabase Auth, Redis, Celery, Storage |

Out of scope:  
- AI/ML categorization  
- Automated investment execution  
- Multi-currency  
- GST/business accounts  

---

# 4.0 High-Level Architecture

## 4.1 Architecture Diagram (ASCII)

```
               ┌──────────────────────────────┐
               │          Users (PWA)          │
               │  React + Supabase Auth (JWT)  │
               └───────────────┬──────────────┘
                               │
                               ▼
                      ┌────────────────┐
                      │   FastAPI API  │
                      │  (Business App)│
                      └──────┬─────────┘
                             │
      ┌──────────────────────┼────────────────────────┐
      ▼                      ▼                        ▼
┌─────────────┐     ┌──────────────────┐       ┌────────────────┐
│  PostgreSQL │     │    MongoDB       │       │     Redis      │
│ Primary DB  │     │ Raw/Staging Data │       │  Pub/Sub & SSE │
└─────────────┘     └──────────────────┘       └────────────────┘
      │                       │                         │
      ▼                       ▼                         ▼
┌──────────────┐     ┌──────────────────────┐   ┌────────────────────┐
│ ETL/Categor. │ --> │ Celery Worker Pool   │   │ Realtime Push Pipe │
│ SpendSense   │     │ Parsing, KPIs, ETL   │   │ SSE Notifications  │
└──────────────┘     └──────────────────────┘   └────────────────────┘

            ┌──────────────────────────────┐
            │ Gmail / Outlook Email Events │
            │  Gmail Pub/Sub / Graph API   │
            └──────────────────────────────┘
```

---

# 5.0 System Components

## 5.1 Frontend (React PWA)
- Responsive layout (mobile-first)  
- Dashboard, SpendSense, Goals, Budgets, Nudges  
- Real-time toasts via Server-Sent Events (SSE)  
- Supabase Auth for authentication  

## 5.2 Backend (FastAPI)
- Authentication proxy  
- Transaction APIs  
- Goal APIs  
- BudgetPilot logic endpoints  
- Realtime Ingestion endpoints  
- SSE endpoint for live events  

## 5.3 Databases
### PostgreSQL (Primary)
Stores:
- transactions (fact/enriched/effective/overrides)  
- goals + budget commits  
- goal progress snapshots  
- activity logs  
- KPI aggregates  
- MoneyMoments tables  

### MongoDB (Secondary)
Stores:
- raw email payloads  
- staging rows  
- import batches  
- parser logs  

---

# 6.0 Data Flow Summary

## 6.1 End-to-End Flow (Email → Dashboard)

```
Email (Gmail/Outlook)
    ↓
Push Notification / API Poll
    ↓
FastAPI ingestion endpoint
    ↓
MongoDB: raw_email, staging_event
    ↓
Celery job: parse_email()
    ↓
Normalization → txn_fact
    ↓
Categorization → txn_enriched
    ↓
vw_txn_effective (override merge)
    ↓
KPI jobs
    ↓
Redis Publish
    ↓
React PWA (SSE)
    ↓
Toast / Dashboard update
```

---

# 7.0 Technology Choices (Binding Requirements)

| Layer | Technology | Reason |
|--------|------------|--------|
| Auth | Supabase Auth | secure, quick, social login (Gmail) |
| Backend | FastAPI | fast, async, typed, robust |
| DB | PostgreSQL | transactional integrity |
| Raw data | MongoDB | schema-free raw payloads |
| Worker | Celery | distributed pipelines |
| Cache | Redis | low-latency pub/sub |
| Frontend | React | PWA-ready, scalable |
| Email | Gmail Pub/Sub, Outlook Graph | real-time ingestion |

---

# 8.0 Constraints & Assumptions

### 8.1 Constraints
- All users authenticated with Supabase Auth  
- Primary currency: INR  
- Statement parsing is rule-based  

### 8.2 Assumptions
- Users will authorize Gmail and/or Outlook  
- 95% of Indian bank SMS/email patterns are covered  
- BudgetPilot templates are extensible  

---

# 9.0 Acceptance Criteria for Module 01
- The architecture supports all modules  
- Each module connects through defined interfaces  
- Data flows allow traceability (audit-ready)  
- Realtime ingestion works for Gmail + Outlook  
- All backend requests authenticated  

---

# END OF MODULE 01
