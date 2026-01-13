#!/bin/bash
# Create .env file in the correct location

set -e

BACKEND_DIR="/opt/mvp-backend/backend"

echo "📝 Creating .env file..."

# Ensure directory exists
if [ ! -d "$BACKEND_DIR" ]; then
    echo "❌ Directory $BACKEND_DIR does not exist!"
    echo "Please run the installation script first or create the directory:"
    echo "  sudo mkdir -p $BACKEND_DIR"
    echo "  sudo chown \$USER:\$USER $BACKEND_DIR"
    exit 1
fi

cd "$BACKEND_DIR"

# Create .env file
cat > .env << 'ENVEOF'
# Environment
ENVIRONMENT=production
LOG_LEVEL=INFO
WORKERS=2

# MongoDB
MONGODB_URI=mongodb+srv://user:password@cluster.mongodb.net/
MONGODB_DB_NAME=monytix_rawdata

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_JWT_SECRET=your-jwt-secret
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# PostgreSQL (uses Supabase connection string)
POSTGRES_URL=postgresql://postgres.user:password@host:port/database

# Redis
REDIS_URL=redis://localhost:6379/0

# Gmail API
GMAIL_CLIENT_ID=your-client-id
GMAIL_CLIENT_SECRET=your-client-secret
GMAIL_REDIRECT_URI=http://localhost:8001/gmail/oauth/callback

# Frontend
FRONTEND_ORIGIN=https://mvp.monytix.ai

# Application Port (host port mapping)
APP_PORT=8001

# Celery
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/0

# Google Cloud Project (optional)
GCP_PROJECT_ID=your-gcp-project-id
GMAIL_PUBSUB_TOPIC=gmail-events
ENVEOF

echo "✅ .env file created at $BACKEND_DIR/.env"
echo ""
echo "⚠️  Please edit the file with your actual values:"
echo "   nano $BACKEND_DIR/.env"
echo "   or"
echo "   vi $BACKEND_DIR/.env"
