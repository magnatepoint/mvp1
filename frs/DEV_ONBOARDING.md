# Monytix – Developer Onboarding Guide

Welcome to the Monytix MVP project. This guide explains how to get started as a backend, frontend, data, or QA engineer, including how to work with Augment.

## 1. Prerequisites

- Python 3.11+
- Node.js 18+
- PostgreSQL 14+
- MongoDB 6+
- Redis 6+
- Supabase project (Auth + Postgres)

## 2. Repositories

- `monytix/backend` – FastAPI app
- `monytix/frontend` – React PWA
- `monytix/docs` – FRS, augment rules, design docs

## 3. Key Documents

- `docs/frs/01_introduction_architecture.md` – high-level overview
- `docs/frs/02_spendsense.md` – transaction engine
- `docs/frs/07_realtime_ingestion.md` – email ingestion
- `docs/augment_rules.md` – rules Augment and devs must follow
- `docs/augment_config.json` – agent config

Read these documents before writing code.

## 4. Local Backend Setup

1. Create `.env` from `.env.example` in `backend/`.
2. Configure Postgres, MongoDB, and Redis URLs.
3. Install dependencies:
   ```bash
   cd backend
   pip install -e .
   ```
4. Run migrations (via Alembic or SQL scripts).
5. Start FastAPI:
   ```bash
   uvicorn app.main:app --reload
   ```
6. Start Celery worker:
   ```bash
   celery -A app.workers.celery_app worker -l info
   ```

## 5. Local Frontend Setup

1. Configure `.env` with API base URL and Supabase keys.
2. Install dependencies:
   ```bash
   cd frontend
   npm install
   npm run dev
   ```

## 6. Working with Augment

- Reference `augment_rules.md` for system constraints.
- Each task from `TASKS_EPICS.md` can be given to Augment:
  - Provide the relevant FRS module path.
  - Ask Augment to generate or update specific files only.
- Always review Augment output before committing.

## 7. Development Conventions

- Use type hints everywhere in Python.
- Follow Pydantic models for request/response schemas.
- Use feature branches per epic/task.
- PRs must include:
  - tests for new behavior
  - notes if acceptance criteria are partially met

## 8. Testing

- Run backend tests:
  ```bash
  cd backend
  pytest
  ```
- Run frontend tests (if configured):
  ```bash
  cd frontend
  npm test
  ```

Only merge code when related Module 10 acceptance criteria are satisfied.
