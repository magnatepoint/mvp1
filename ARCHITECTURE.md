# Monytix MVP - System Architecture

## Table of Contents
1. [Overview](#overview)
2. [High-Level Architecture](#high-level-architecture)
3. [Technology Stack](#technology-stack)
4. [Frontend Architecture](#frontend-architecture)
5. [Backend Architecture](#backend-architecture)
6. [Database Architecture](#database-architecture)
7. [Deployment Architecture](#deployment-architecture)
8. [Data Flow](#data-flow)
9. [Component Interactions](#component-interactions)
10. [Security Architecture](#security-architecture)

---

## Overview

Monytix is a personal finance management platform that helps users track spending, set financial goals, manage budgets, and receive real-time transaction notifications. The system is built as a modern web application with real-time capabilities.

### Key Features
- **SpendSense**: Transaction tracking, categorization, and insights
- **GoalTracker**: Financial goal setting and tracking
- **BudgetPilot**: Budget planning and variance tracking
- **GoalCompass**: Goal progress monitoring and recommendations
- **MoneyMoments**: Behavioral nudges and insights
- **Realtime Ingestion**: Email-based transaction capture (Gmail/Outlook)

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Layer                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Web App    │  │  Mobile (ios/│  │   Desktop    │          │
│  │ (Next.js PWA)│  │   android)   │  │   Browser    │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
└─────────┼──────────────────┼──────────────────┼────────────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │ HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Application Layer                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Frontend (Cloudflare Pages)                 │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐│   │
│  │  │SpendSense│  │Goals     │  │Budget    │  │Moments   ││   │
│  │  │  UI      │  │Tracker   │  │Pilot     │  │          ││   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬────┘│   │
│  └───────┼──────────────┼──────────────┼─────────────┼─────┘   │
│          │              │              │             │          │
│          └──────────────┼──────────────┼─────────────┘          │
│                         │              │                        │
│                         ▼              ▼                        │
│  ┌──────────────────────────────────────────────────────┐      │
│  │         API Client Layer (lib/api/)                   │      │
│  │  - Authentication (Supabase JWT)                     │      │
│  │  - REST API calls to backend                        │      │
│  │  - SSE client for real-time updates                 │      │
│  └───────────────────────┬──────────────────────────────┘      │
└──────────────────────────┼──────────────────────────────────────┘
                           │ REST API / SSE
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Backend Layer (Coolify/Docker)              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              FastAPI Application                         │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐│ │
│  │  │SpendSense│  │Goals     │  │Budget    │  │Gmail     ││ │
│  │  │Routes    │  │Routes    │  │Routes    │  │Routes    ││ │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘│ │
│  └───────┼──────────────┼──────────────┼─────────────┼──────┘   │
│          │              │              │             │           │
│          ▼              ▼              ▼             ▼           │
│  ┌──────────────────────────────────────────────────────┐      │
│  │         Service Layer                                 │      │
│  │  - SpendSenseService                                 │      │
│  │  - GoalsService                                      │      │
│  │  - BudgetService                                     │      │
│  │  - GmailService                                      │      │
│  └───────────────────────┬──────────────────────────────┘      │
│                          │                                      │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────┐      │
│  │         Repository Layer                              │      │
│  │  - Database queries (asyncpg)                        │      │
│  │  - Data transformations                              │      │
│  └───────────────────────┬──────────────────────────────┘      │
└──────────────────────────┼──────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  PostgreSQL  │  │   MongoDB    │  │    Redis    │
│  (Primary DB)│  │ (Raw/Staging)│  │ (Queue/SSE)  │
└──────────────┘  └──────────────┘  └──────────────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │   Celery Workers       │
              │  - Email Parsing       │
              │  - Transaction ETL     │
              │  - KPI Calculation     │
              │  - ML Training         │
              └────────────────────────┘
```

---

## Technology Stack

### Frontend
- **Framework**: Next.js 16.1.2 (React 19.2.3)
- **Language**: TypeScript
- **Styling**: Tailwind CSS 4
- **Charts**: Recharts 3.6.0
- **Authentication**: Supabase Auth (@supabase/supabase-js)
- **Deployment**: Cloudflare Pages (Edge Runtime)
- **Build Tool**: Turbopack

### Backend
- **Framework**: FastAPI 0.115.x
- **Language**: Python 3.11+
- **ASGI Server**: Uvicorn
- **Task Queue**: Celery 5.4+ with Redis broker
- **Database Drivers**: 
  - asyncpg (PostgreSQL)
  - pymongo (MongoDB)
- **Authentication**: Supabase JWT validation
- **Deployment**: Docker + Coolify

### Databases
- **PostgreSQL 14+**: Primary transactional database
- **MongoDB 6+**: Raw email storage, staging data
- **Redis 6+**: Celery broker, SSE pub/sub, caching

### External Services
- **Supabase**: Authentication, user management
- **Gmail API**: Email ingestion via Pub/Sub
- **Outlook Graph API**: Email ingestion (future)
- **Cloudflare**: CDN, DDoS protection, Pages hosting

---

## Frontend Architecture

### Directory Structure
```
mony_mvp/
├── app/                    # Next.js App Router
│   ├── page.tsx           # Main entry point
│   ├── auth/              # Auth callbacks
│   └── layout.tsx         # Root layout
├── components/            # React components
│   ├── spendsense/       # SpendSense module
│   │   ├── SpendSense.tsx
│   │   ├── insights/     # Insights UI components
│   │   └── ...
│   ├── budgetpilot/      # BudgetPilot module
│   ├── goals/            # Goals module
│   └── ...
├── lib/                   # Utilities
│   ├── api/              # API client functions
│   │   ├── client.ts    # Base API client
│   │   ├── spendsense.ts
│   │   ├── goals.ts
│   │   └── budget.ts
│   └── theme/            # Theme utilities
├── types/                 # TypeScript types
└── public/                # Static assets
```

### Key Components

#### 1. **Authentication Flow**
- Uses Supabase SSR for session management
- JWT tokens stored in HTTP-only cookies
- Session validation on each API call

#### 2. **API Client Layer** (`lib/api/`)
- Centralized API client with authentication
- Automatic token injection
- Error handling and retry logic
- URL normalization and validation

#### 3. **Component Architecture**
- **Feature-based organization**: Each module (SpendSense, BudgetPilot, etc.) has its own directory
- **Reusable components**: Shared UI components (cards, modals, charts)
- **State management**: React hooks and local state (no global state library)
- **Real-time updates**: SSE client for live transaction notifications

#### 4. **Routing**
- Next.js App Router with file-based routing
- Dynamic routes for detail pages
- Edge runtime for Cloudflare Pages compatibility

---

## Backend Architecture

### Directory Structure
```
backend/
├── app/
│   ├── main.py                    # FastAPI app initialization
│   ├── core/                      # Core utilities
│   │   ├── config.py             # Configuration
│   │   └── security.py           # Auth utilities
│   ├── auth/                      # Authentication
│   │   ├── routes.py             # Auth endpoints
│   │   ├── dependencies.py       # Auth dependencies
│   │   └── service.py            # Auth service
│   ├── spendsense/               # SpendSense module
│   │   ├── routes.py             # API routes
│   │   ├── service.py            # Business logic
│   │   ├── models.py             # Pydantic models
│   │   ├── etl/                  # ETL pipeline
│   │   └── ml/                   # ML models
│   ├── goals/                    # Goals module
│   │   ├── routes.py
│   │   ├── service.py
│   │   ├── goal_planner.py       # Goal planning logic
│   │   └── rules/                # Goal rules engine
│   ├── budgetpilot/              # BudgetPilot module
│   │   ├── routes.py
│   │   ├── service.py
│   │   └── recommendation_engine.py
│   ├── gmail/                    # Gmail integration
│   │   ├── routes.py
│   │   ├── service.py
│   │   ├── subscriber.py         # Pub/Sub subscriber
│   │   └── tasks.py              # Celery tasks
│   ├── dependencies/             # Shared dependencies
│   │   ├── database.py           # DB connection pool
│   │   └── auth.py               # Auth dependencies
│   └── celery_app.py             # Celery configuration
├── migrations/                    # SQL migration scripts
└── requirements.txt              # Python dependencies
```

### Key Components

#### 1. **API Layer** (FastAPI Routes)
- RESTful API endpoints under `/v1/`
- Automatic OpenAPI documentation
- Request/response validation with Pydantic
- CORS configuration for frontend

#### 2. **Service Layer**
- Business logic separation
- Transaction orchestration
- Data validation and transformation
- Error handling

#### 3. **Repository Layer**
- Database query abstraction
- Connection pooling (asyncpg)
- Transaction management
- Query optimization

#### 4. **Task Queue** (Celery)
- Async task processing
- Email parsing tasks
- ETL pipeline tasks
- KPI calculation tasks
- ML model training tasks

---

## Database Architecture

### PostgreSQL (Primary Database)

#### Core Tables
- **`txn_fact`**: Canonical transaction facts (immutable)
- **`txn_parsed`**: Parsed transaction data
- **`txn_enriched`**: Categorized/enriched transactions
- **`txn_override`**: User corrections/overrides
- **`vw_txn_effective`**: Materialized view for effective transactions

#### Goals & Budgets
- **`goals`**: User financial goals
- **`goal_progress`**: Goal progress snapshots
- **`budget_commit`**: Committed budgets
- **`budget_variance`**: Budget vs actual calculations

#### Metadata
- **`dim_category`**: Category taxonomy
- **`dim_subcategory`**: Subcategory taxonomy
- **`dim_merchant`**: Merchant master data
- **`merchant_rules`**: Categorization rules

#### Real-time Ingestion
- **`gmail_state`**: Gmail watch state
- **`email_event`**: Email events
- **`email_ingest`**: Ingestion logs

### MongoDB (Secondary Database)

#### Collections
- **`email_raw`**: Raw email payloads (JSON/MIME)
- **`txn_staging`**: Staging area for extracted transactions
- **`email_parse_logs`**: Parser logs and errors

### Redis

#### Usage
- **Celery Broker**: Task queue
- **SSE Pub/Sub**: Real-time notifications
- **Caching**: Session data, KPI cache

---

## Deployment Architecture

### Frontend Deployment (Cloudflare Pages)

```
GitHub Repository
      │
      ▼
Cloudflare Pages
      │
      ├── Build Process
      │   ├── npm install
      │   ├── next build
      │   └── @cloudflare/next-on-pages
      │
      └── Edge Runtime
          ├── Static assets (CDN)
          ├── Edge Functions (API routes)
          └── Environment Variables
```

**Configuration**:
- Build command: `npx @cloudflare/next-on-pages@1`
- Node version: 22.16.0
- Edge runtime for dynamic routes
- Environment variables: `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_SUPABASE_URL`, etc.

### Backend Deployment (Coolify/Docker)

```
GitHub Repository
      │
      ▼
Coolify Platform
      │
      ├── Docker Build
      │   ├── Dockerfile
      │   ├── docker-compose.yml
      │   └── Environment Variables
      │
      └── Services
          ├── FastAPI (Port 8000)
          ├── Celery Worker
          ├── Celery Beat
          └── Gmail Subscriber
```

**Configuration**:
- Docker-based deployment
- Environment variables for DB connections, API keys
- Health check endpoints
- Auto-restart on failure

### Database Deployment

- **PostgreSQL**: Managed instance (Supabase or self-hosted)
- **MongoDB**: Managed instance or self-hosted
- **Redis**: Managed instance or self-hosted

---

## Data Flow

### 1. Transaction Ingestion Flow

```
Email (Gmail/Outlook)
    ↓
Pub/Sub Push / Webhook
    ↓
FastAPI /v1/gmail/push
    ↓
Store Raw Email (MongoDB)
    ↓
Celery Task: parse_email_event()
    ↓
Extract Transaction Data
    ↓
Insert to txn_staging (MongoDB)
    ↓
ETL Pipeline:
    - Normalize
    - Categorize (Rules + ML)
    - Enrich
    ↓
Insert to txn_fact (PostgreSQL)
    ↓
Update vw_txn_effective
    ↓
Redis Publish (SSE Event)
    ↓
Frontend SSE Client
    ↓
UI Update + Toast Notification
```

### 2. User Action Flow (e.g., View Transactions)

```
User clicks "View Transactions"
    ↓
Frontend: fetchTransactions()
    ↓
API Client: GET /v1/spendsense/transactions
    ↓
FastAPI Route Handler
    ↓
SpendSenseService.list_transactions()
    ↓
Query vw_txn_effective (PostgreSQL)
    ↓
Apply filters, pagination
    ↓
Return JSON response
    ↓
Frontend renders transaction list
```

### 3. Budget Commit Flow

```
User selects budget recommendation
    ↓
Frontend: commitBudget()
    ↓
API: POST /v1/budget/commit
    ↓
BudgetService.commit_budget()
    ↓
Insert to budget_commit table
    ↓
Calculate initial variance
    ↓
Return committed budget
    ↓
Frontend updates UI
```

---

## Component Interactions

### Frontend ↔ Backend

1. **Authentication**
   - Frontend: Supabase Auth → JWT token
   - Backend: Validates JWT → Extracts user_id
   - All API calls include JWT in Authorization header

2. **API Communication**
   - RESTful endpoints for CRUD operations
   - SSE endpoint for real-time updates
   - Error handling with user-friendly messages

3. **Data Synchronization**
   - Optimistic updates in frontend
   - Server-side validation
   - Conflict resolution

### Backend ↔ Database

1. **PostgreSQL**
   - Connection pooling (asyncpg)
   - Prepared statements for security
   - Transactions for data consistency

2. **MongoDB**
   - Document storage for raw data
   - Flexible schema for staging
   - Indexed queries for performance

3. **Redis**
   - Pub/Sub for SSE events
   - Celery task queue
   - Session caching

### Backend ↔ External Services

1. **Supabase**
   - JWT validation
   - User management
   - Database (if using Supabase Postgres)

2. **Gmail API**
   - Pub/Sub subscriptions
   - Email retrieval
   - Watch renewal

---

## Security Architecture

### Authentication & Authorization

1. **JWT-based Auth**
   - Tokens issued by Supabase
   - Validated on every API request
   - User ID extracted from token claims

2. **Row-Level Security**
   - All queries filtered by `user_id`
   - No cross-user data access
   - Database-level constraints

3. **API Security**
   - CORS configuration
   - Rate limiting (future)
   - Input validation (Pydantic)
   - SQL injection prevention (parameterized queries)

### Data Security

1. **Encryption**
   - HTTPS for all communications
   - Encrypted database connections
   - Secure environment variable storage

2. **Data Privacy**
   - No sensitive data in logs
   - PII handling compliance
   - Secure email storage

---

## Performance Considerations

### Frontend
- **Code Splitting**: Next.js automatic code splitting
- **Image Optimization**: Next.js Image component
- **Caching**: Static assets via Cloudflare CDN
- **Lazy Loading**: Component-level lazy loading

### Backend
- **Connection Pooling**: Database connection pools
- **Async Operations**: FastAPI async/await
- **Caching**: Redis for frequently accessed data
- **Background Tasks**: Celery for heavy operations

### Database
- **Indexes**: Strategic indexes on frequently queried columns
- **Materialized Views**: Pre-computed aggregations
- **Query Optimization**: Efficient SQL queries
- **Partitioning**: Future consideration for large tables

---

## Monitoring & Observability

### Logging
- Structured logging in backend
- Error tracking
- Request/response logging

### Health Checks
- `/health` endpoint for backend
- Database connectivity checks
- Service status monitoring

### Metrics (Future)
- API response times
- Error rates
- Database query performance
- Task queue metrics

---

## Scalability Considerations

### Horizontal Scaling
- **Frontend**: Cloudflare Pages auto-scales
- **Backend**: Multiple FastAPI instances behind load balancer
- **Celery Workers**: Multiple worker processes
- **Database**: Read replicas for PostgreSQL

### Vertical Scaling
- Database instance sizing
- Redis memory allocation
- Worker process counts

---

## Future Enhancements

1. **Mobile Apps**: Native iOS/Android apps
2. **Multi-currency**: Support for multiple currencies
3. **Investment Tracking**: Expanded investment features
4. **AI/ML**: Enhanced categorization with ML
5. **Analytics**: Advanced analytics and reporting
6. **Collaboration**: Shared budgets/goals

---

## References

- [Project Structure](./frs/PROJECT_STRUCTURE.md)
- [Developer Onboarding](./frs/DEV_ONBOARDING.md)
- [API Reference](./frs/09_api_ref.md)
- [Data Dictionary](./frs/08_data_dictionary.md)
