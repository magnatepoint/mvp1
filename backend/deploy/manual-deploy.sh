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
if [ -d "/opt/mvp-backend" ]; then
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
    
    if [ -f "deploy/scripts/run-migrations.sh" ]; then
        echo -e "${BLUE}🗄️  Running database migrations...${NC}"
        bash deploy/scripts/run-migrations.sh || echo -e "${YELLOW}⚠️  Migrations failed (continuing anyway)${NC}"
    fi
    
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
    # Deploy via SSH
    echo ""
    echo -e "${BLUE}🔐 Connecting to server...${NC}"
    
    ssh "$SERVER_USER@$SERVER_HOST" << ENDSSH
        set -e
        cd $DEPLOY_DIR
        
        # Pull latest code
        echo "📥 Pulling latest code..."
        git fetch origin
        git reset --hard origin/main
        git clean -fd
        
        # Build images
        echo "🔨 Building Docker images..."
        docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache
        
        # Run migrations
        if [ -f "deploy/scripts/run-migrations.sh" ]; then
            echo "🗄️  Running database migrations..."
            bash deploy/scripts/run-migrations.sh || echo "⚠️  Migrations failed (continuing anyway)"
        fi
        
        # Restart services
        echo "🛑 Stopping existing services..."
        docker-compose -f docker-compose.yml -f docker-compose.prod.yml down || true
        
        echo "🚀 Starting services..."
        docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
        
        echo "⏳ Waiting for services to be ready..."
        sleep 15
        
        # Health check
        if [ -f "deploy/scripts/health-check.sh" ]; then
            echo "🏥 Running health check..."
            bash deploy/scripts/health-check.sh || echo "⚠️  Health check had issues"
        fi
        
        echo ""
        echo "📊 Service Status:"
        docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps
        
        echo ""
        echo "✅ Deployment complete!"
ENDSSH
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✅ Deployment complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
