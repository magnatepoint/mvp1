#!/bin/bash
# Manual deployment script - run this from your local machine or server

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Manual Deployment${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if running locally or on server
if [ -d "/opt/mvp-backend" ] && [ -z "$SERVER_HOST" ] && [ "$FORCE_REMOTE" != "true" ]; then
    # Running on server
    SERVER_MODE=true
    DEPLOY_DIR="/opt/mvp-backend/backend"
    echo -e "${BLUE}📍 Running on server${NC}"
else
    # Running locally - need to SSH to server
    SERVER_MODE=false
    
    # Check for SSH parameters
    if [ -z "$SERVER_USER" ] || [ -z "$SERVER_HOST" ]; then
        echo -e "${YELLOW}⚠️  Running from local machine${NC}"
        echo -e "${BLUE}Please set environment variables:${NC}"
        echo "  export SERVER_USER=your-username"
        echo "  export SERVER_HOST=your-server-ip"
        echo ""
        read -p "Enter server username: " SERVER_USER
        read -p "Enter server host (IP or domain): " SERVER_HOST
    fi
    
    DEPLOY_DIR="/opt/mvp-backend/backend"
    echo -e "${BLUE}📍 Will deploy to: ${SERVER_USER}@${SERVER_HOST}${NC}"
fi

# Deployment function
deploy() {
    local target_dir=$1
    
    echo -e "${BLUE}📥 Pulling latest code...${NC}"
    cd "$target_dir"
    git fetch origin
    git reset --hard origin/main
    git clean -fd
    
    echo -e "${BLUE}🔨 Building Docker images...${NC}"
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache
    
    
    echo -e "${BLUE}🛑 Stopping existing services...${NC}"
    # Stop any containers using port 8000
    docker ps --format '{{.Names}}' | grep -E "(mvp|backend)" | xargs docker stop 2>/dev/null || true
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml down || true
    
    echo -e "${BLUE}🚀 Starting services...${NC}"
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
    
    echo -e "${BLUE}⏳ Waiting for services to be ready...${NC}"
    sleep 15
    
    if [ -f "deploy/scripts/health-check.sh" ]; then
        echo -e "${BLUE}🏥 Running health check...${NC}"
        if bash deploy/scripts/health-check.sh; then
            echo -e "${GREEN}✅ All services are healthy!${NC}"
        else
            echo -e "${YELLOW}⚠️  Health check had issues${NC}"
        fi
    fi
    
    echo ""
    echo -e "${BLUE}📊 Service Status:${NC}"
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps
}

# Main execution
if [ "$SERVER_MODE" = true ]; then
    # Deploy directly on server
    deploy "$DEPLOY_DIR"
else
    echo ""
    echo -e "${BLUE}🔐 Connecting to server...${NC}"

    # 1. Update Code (clean first to remove old artifacts, but this will also remove secrets if we don't re-upload them)
    echo -e "${BLUE}📥 Updating code on server...${NC}"
    ssh "$SERVER_USER@$SERVER_HOST" "cd $DEPLOY_DIR && git fetch origin && git reset --hard origin/main && git clean -fd"

    # 2. Upload Secrets
    echo -e "${BLUE}🔑 Uploading secrets...${NC}"
    if [ -f "$BACKEND_DIR/gmail-pubsub-key.json" ]; then
        echo "   Uploading gmail-pubsub-key.json..."
        scp "$BACKEND_DIR/gmail-pubsub-key.json" "$SERVER_USER@$SERVER_HOST:$DEPLOY_DIR/"
    else
        echo "   ⚠️ gmail-pubsub-key.json not found locally. Build might fail if Dockerfile expects it."
    fi
    
    if [ -f "$BACKEND_DIR/.env" ]; then
        echo "   Uploading .env..."
        scp "$BACKEND_DIR/.env" "$SERVER_USER@$SERVER_HOST:$DEPLOY_DIR/"
    fi

    # 3. Upload uncommitted changes (bundle local fixes)
    echo -e "${BLUE}📤 Bundling and uploading local modifications...${NC}"
    MOD_FILES=(
        "Dockerfile"
        "app/main.py"
        "app/spendsense/models.py"
        "app/spendsense/routes.py"
        "app/spendsense/service.py"
        "migrations/060_create_spendsense_mvs.sql"
        "deploy/scripts/health-check.sh"
        "deploy/scripts/setup-cloudflare-tunnel.sh"
        "docker-compose.prod.yml"
        "docker-compose.yml"
        "start.sh"
        "migrations/061_create_spendsense_dashboard_summary_mv.sql"
        ".dockerignore"
    )
    
    # Check if untracked files exist
    if [ -f "$BACKEND_DIR/deploy/scripts/kill-port-8001.sh" ]; then
        MOD_FILES+=("deploy/scripts/kill-port-8001.sh")
    fi
    if [ -f "$BACKEND_DIR/deploy/scripts/run_migrations.py" ]; then
        MOD_FILES+=("deploy/scripts/run_migrations.py")
    fi

    # Create a temporary tarball
    TARBALL="/tmp/backend_mods_$(date +%s).tar.gz"
    tar -czf "$TARBALL" -C "$BACKEND_DIR" "${MOD_FILES[@]}"
    
    echo "   Uploading modifications archive..."
    scp "$TARBALL" "$SERVER_USER@$SERVER_HOST:/tmp/backend_mods.tar.gz"
    rm "$TARBALL"

    # 4. Build and Deploy (Robust Method)
    echo -e "${BLUE}📜 Generating deployment script...${NC}"
    
    # Generate a temporary script to run on the server
    # We use a unique name to avoid conflicts
    REMOTE_SCRIPT="/tmp/deploy_${APP_PORT:-8001}_$(date +%s).sh"
    
    cat > .deploy_payload.sh <<EOF
#!/bin/bash
set -e

# Configuration
export DEPLOY_DIR="$DEPLOY_DIR"
export REPO_DIR="/opt/mvp-backend"
export APP_PORT="${APP_PORT:-8001}"

echo "📍 Server: \$(hostname)"
echo "📍 Repo Root: \$REPO_DIR"
echo "📍 Deploy Dir: \$DEPLOY_DIR"
echo "📍 Port: \$APP_PORT"

# Ensure directories exist
mkdir -p "\$DEPLOY_DIR"

# Navigate to Repo Root to handle Git
cd "\$REPO_DIR"

# Check Git
if [ ! -d ".git" ]; then
    echo "⚠️  .git directory missing."
    # We'll rely on the parent script having handled this or the tarball providing the files
else
    # echo "📥 Updating code (handled by parent script)..."
    # git fetch origin
    # git reset --hard origin/main
    true
fi

# Clean state before applying modifications
echo "🧹 Cleaning up repository..."
git clean -fd

# Apply manual modifications from tarball
if [ -f "/tmp/backend_mods.tar.gz" ]; then
    echo "📦 Applying local modifications from archive..."
    tar -xzf /tmp/backend_mods.tar.gz -C "\$DEPLOY_DIR"
    rm /tmp/backend_mods.tar.gz
fi

# Now go to the backend directory for Docker operations
cd "\$DEPLOY_DIR"

echo "🔨 Building Docker images..."
# Explicitly pass APP_PORT to docker-compose
APP_PORT=\$APP_PORT docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache

echo "🛑 Stopping existing services..."

# 1. Aggressively find and stop any container using the target port
echo "   Checking for containers on port \$APP_PORT..."
CONFLICTING_CONTAINER=\$(docker ps -q --filter "publish=\$APP_PORT")
if [ ! -z "\$CONFLICTING_CONTAINER" ]; then
    echo "   ⚠️  Found container holding port \$APP_PORT. Force stopping..."
    docker stop \$CONFLICTING_CONTAINER || true
    docker rm \$CONFLICTING_CONTAINER || true
fi

# 2. Standard Compose Down
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down --remove-orphans || true

echo "🚀 Starting services..."
APP_PORT=\$APP_PORT docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

echo "⏳ Waiting for startup (15s)..."
sleep 15

echo "🗄️ Running database migrations in container..."
docker exec mvp-backend python3 deploy/scripts/run_migrations.py || echo "⚠️ Migrations failed (continuing anyway)"

echo ""
echo "📊 Container Status (docker ps):"
docker ps | grep -E "backend|mvp" || echo "⚠️ No backend containers found!"

echo ""
echo "🩺 Service Logs (tail):"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs --tail=20

echo ""
echo "✅ Deployment script finished successfully."
EOF

    # Upload and Execute
    echo -e "${BLUE}📤 Uploading deployment script...${NC}"
    scp .deploy_payload.sh "$SERVER_USER@$SERVER_HOST:$REMOTE_SCRIPT"
    rm .deploy_payload.sh # Clean up local
    
    echo -e "${BLUE}🏃 Executing on server...${NC}"
    ssh "$SERVER_USER@$SERVER_HOST" "bash $REMOTE_SCRIPT && rm $REMOTE_SCRIPT"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✅ Deployment complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
