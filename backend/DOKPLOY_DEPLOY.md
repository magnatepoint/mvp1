# Deploy MVP Backend to Dokploy

This guide covers deploying the FastAPI backend to [Dokploy](https://dokploy.com/) (self-hosted PaaS). The app supports the `PORT` environment variable so Dokploy can assign the container port.

---

## Option A: Docker application (recommended)

Use a single-container deployment. Postgres and Redis must be external (e.g. Dokploy databases, Supabase Postgres, or another host).

### 1. Create application in Dokploy

- In Dokploy dashboard: **Applications** → **Create Application**.
- Choose **Docker** (or **Git** if you want auto-deploy from GitHub).
- **Name:** e.g. `mvp-backend`.

### 2. Connect repository (if using Git)

- **Source:** GitHub (or your Git provider).
- **Repository:** `magnatepoint/mvp1` (or your fork).
- **Branch:** `main`.
- **Build Context:** set to **`backend`** (so the Dockerfile and `app/` are in context).  
  If Dokploy only allows repo root, set **Dockerfile path** to `backend/Dockerfile` and **Build context** to `backend` if the UI has a “context” field; otherwise use repo root and ensure the Dockerfile path is `backend/Dockerfile` and that the build context includes the `backend` folder.

### 3. Build settings

- **Dockerfile path:** `Dockerfile` (if context is `backend`) or `backend/Dockerfile` (if context is repo root).
- **Port:** Dokploy may expose a port (e.g. 8000). The app reads **`PORT`** at runtime (default `8001`). Set the container port in Dokploy to match (e.g. 8001), or let Dokploy set `PORT` and map its proxy to that port.

### 4. Environment variables

Add these in Dokploy’s **Environment** / **Env** section. Use your own values; do not commit secrets.

| Variable | Required | Example / notes |
|----------|----------|------------------|
| `ENVIRONMENT` | Yes | `production` |
| `POSTGRES_URL` | Yes | `postgresql://user:pass@host:5432/dbname` (Supabase or Dokploy Postgres) |
| `SUPABASE_URL` | Yes | `https://xxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Yes | From Supabase dashboard |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | From Supabase dashboard |
| `SUPABASE_JWT_SECRET` | Yes | From Supabase → Settings → API → JWT secret |
| `FRONTEND_ORIGIN` | Yes | `https://your-frontend.com` (no trailing slash) |
| `REDIS_URL` | Yes* | `redis://host:6379/0` (Dokploy Redis or external) |
| `GMAIL_CLIENT_ID` | Yes | OAuth client ID |
| `GMAIL_CLIENT_SECRET` | Yes | OAuth client secret |
| `GMAIL_REDIRECT_URI` | Yes | `https://your-api-domain.com/v1/gmail/oauth/callback` (or your Gmail callback URL) |
| `GMAIL_TOKEN_URI` | No | `https://oauth2.googleapis.com/token` (default) |
| `GCP_PROJECT_ID` | No | If using Gmail Pub/Sub |
| `GMAIL_PUBSUB_TOPIC` | No | e.g. `gmail-events` |
| `GOOGLE_CREDENTIALS_JSON` | No | JSON string of GCP service account key (if using Pub/Sub) |
| `LOG_LEVEL` | No | `INFO` |
| `PORT` | No | Set by Dokploy if they inject it; otherwise app uses `8001` |

\* Redis is required for session/workers; use a Dokploy Redis instance or external Redis.

Reference: `backend/.env.production.example`.

### 5. Build path and Docker context (important)

Your **Build Path** is `/backend`. Then:

- **Docker File:** use **`Dockerfile`** (relative to build path), not `backend/Dockerfile`. So the full path Dokploy uses is build path + this field = `backend` + `Dockerfile` → correct.
- **Docker Context Path:** set to **`.`** (so the context is the same as Build Path, i.e. the `backend` folder). If you leave it empty and the default is repo root, the build will fail because `app/` and `requirements.txt` are under `backend/`.

If your UI only has “Build Path” and no separate “Docker Context Path”, then Build Path `backend` usually means “use `backend` as the context” and **Docker File** should be **`Dockerfile`** (file at `backend/Dockerfile`).

### 6. Deploy

- Save and trigger **Deploy** / **Build**. First build may take a few minutes.
- After deploy, open the app URL (e.g. `https://your-app.dokploy.com`). Health: `https://your-app.dokploy.com/health`.

### 7. Run database migrations (one-time)

Migrations are not run automatically. Options:

- **Dokploy shell/console:**  
  Open a shell in the running backend container and run your migration command (e.g. `python deploy/scripts/run_migrations.py` or `psql` with migration SQL), **or**
- **One-off job:**  
  In Dokploy, run a one-off container with the same image and env, and the same migration command.

Example (adjust to your migration script):

```bash
# Inside backend container or one-off job
cd /app && python deploy/scripts/run_migrations.py
# Or apply SQL manually: psql $POSTGRES_URL -f migrations/001_spendsense_schema.sql (and others in order)
```

---

## Troubleshooting

### "No such container: select-a-container???"

This means Dokploy is still using a **placeholder** instead of a real container:

1. **Container selection**
   - In the **backend** application screen, check any dropdown or field that asks for a **container** (e.g. “Select container”, “Target container”, “Run in container”, “Link container”).
   - Make sure you **choose the backend application’s container** (or the service you created), not the default “select-a-container” option.
   - If the app has never been built/run, there is no container yet: run **Build** first, then **Deploy/Run**, then use that container everywhere.

2. **Build first**
   - If you only configured the app and clicked something that assumes a container (e.g. “Execute”, “Logs”, “Restart”), the container won’t exist until the first build and deploy succeed.
   - Do: **Save** → **Build** (wait for success) → **Deploy** (or **Start**). After that, any “container” field should list the backend container.

3. **Where the placeholder appears**
   - Check: **Settings**, **Deploy** step, **Schedules**, or any “Execute command in container” / “Run” action. Replace every “select-a-container” (or similar) with the actual backend service/container.

4. **Dokploy version**
   - You’re on **v0.26.5**; the “Update Available” may fix UI bugs. Consider updating and retrying.

---

## Option B: Docker Compose on Dokploy

If Dokploy supports **Docker Compose** and you want backend + Redis in one stack:

1. In Dokploy, create a **Docker Compose** application.
2. Use a compose file that includes:
   - Service built from `backend/Dockerfile` (context `backend`).
   - Redis service (e.g. `redis:7-alpine`).
   - Env for backend: `POSTGRES_URL`, Supabase vars, `FRONTEND_ORIGIN`, `REDIS_URL=redis://redis:6379/0`, Gmail vars, etc.
3. Set the backend service port (e.g. 8001) and ensure `PORT` is set if Dokploy expects it.

The existing `backend/docker-compose.yml` can be used as reference; ensure `POSTGRES_URL` and other env vars point to your production DB and Redis.

---

## Post-deploy

- **CORS:** Backend allows origins from `FRONTEND_ORIGIN` and common localhost ports. Set `FRONTEND_ORIGIN` to your frontend URL.
- **Health:** `GET /health` should return 200.
- **Docs:** `GET /docs` (if enabled in production) for Swagger UI.

---

## Optional: Celery workers

This deploy runs only the FastAPI app. For background tasks (e.g. file processing, Gmail sync), run Celery worker and beat separately (same image, different command, same env and `REDIS_URL`). You can add them as extra services in Docker Compose or as separate Dokploy applications.
