#!/bin/bash
# Remote deployment script (called by GitHub Actions)
# This script runs on the Ubuntu server

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
echo -e "${BLUE}   Automated Deployment${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

cd "$BACKEND_DIR"

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    exit 1
fi

# Load environment
export $(grep -v '^#' .env | xargs)

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose not found${NC}"
    exit 1
fi

# Pull latest code
echo -e "${BLUE}📥 Pulling latest code...${NC}"
git fetch origin
git reset --hard origin/main
git clean -fd

# Build Docker images
echo -e "${BLUE}🔨 Building Docker images...${NC}"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache

# Run migrations
if [ -f "deploy/scripts/run-migrations.sh" ]; then
    echo -e "${BLUE}🗄️  Running database migrations...${NC}"
    bash deploy/scripts/run-migrations.sh || echo -e "${YELLOW}⚠️  Migrations failed (continuing anyway)${NC}"
fi

# Stop existing services
echo -e "${BLUE}🛑 Stopping existing services...${NC}"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down || true

# Start services
echo -e "${BLUE}🚀 Starting services...${NC}"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Wait for services
echo -e "${BLUE}⏳ Waiting for services to be ready...${NC}"
sleep 15

# Health check
if [ -f "deploy/scripts/health-check.sh" ]; then
    echo -e "${BLUE}🏥 Running health check...${NC}"
    if bash deploy/scripts/health-check.sh; then
        echo -e "${GREEN}✅ All services are healthy!${NC}"
    else
        echo -e "${YELLOW}⚠️  Health check had issues${NC}"
        exit 1
    fi
fi

# Show service status
echo ""
echo -e "${BLUE}📊 Service Status:${NC}"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✅ Deployment complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
