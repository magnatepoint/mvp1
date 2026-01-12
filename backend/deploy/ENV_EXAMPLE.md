# Complete .env File Example

```bash
# Environment
ENVIRONMENT=production
LOG_LEVEL=INFO
WORKERS=2

# MongoDB (if still using)
MONGODB_URI=mongodb+srv://user:password@cluster.mongodb.net/
MONGODB_DB_NAME=your-database-name

# Supabase
SUPABASE_URL=https://vwagtikpxbhjrffolrqn.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
SUPABASE_JWT_SECRET=your-jwt-secret-here

# Frontend Origin (for CORS)
FRONTEND_ORIGIN=https://mvp.monytix.ai

# PostgreSQL (uses Supabase connection string)
POSTGRES_URL=postgresql://user:password@host:5432/database

# Redis (use 'redis' as hostname when running in Docker)
REDIS_URL=redis://redis:6379/0

# Gmail API
GMAIL_CLIENT_ID=your-gmail-client-id
GMAIL_CLIENT_SECRET=your-gmail-client-secret
GMAIL_REDIRECT_URI=https://api.monytix.ai/gmail/oauth/callback
GMAIL_TOKEN_URI=https://oauth2.googleapis.com/token

# Google Cloud Pub/Sub (optional)
GCP_PROJECT_ID=your-gcp-project-id
GMAIL_PUBSUB_TOPIC=gmail-events
GOOGLE_APPLICATION_CREDENTIALS=/app/gmail-pubsub-key.json

# Celery (use 'redis' as hostname when running in Docker)
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# Base Directory
BASE_DIR=/app

# Cloud Backup (optional - set after rclone setup)
# CLOUD_STORAGE=gdrive
# CLOUD_REMOTE=gdrive:mvp-backups
# GPG_RECIPIENT=your-gpg-key-id
```

## Important Notes:

1. **GMAIL_REDIRECT_URI**: Must use `https://api.monytix.ai` (not localhost) in production
2. **REDIS_URL**: Use `redis://redis:6379/0` (not localhost) when running in Docker
3. **FRONTEND_ORIGIN**: Required for CORS - set to your frontend domain (e.g., `https://mvp.monytix.ai`)
4. **CORS Configuration**: The backend allows:
   - Frontend web origin (from FRONTEND_ORIGIN)
   - All origins for mobile apps (iOS, Android, Flutter) - mobile apps don't have traditional origins
   - Security is enforced through authentication tokens, not CORS
5. **Cloudflare config**: Should be in `deploy/cloudflare/config.yml`, NOT in `.env`
