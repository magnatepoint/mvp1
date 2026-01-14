#!/bin/bash
# Health check script for all services

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Load environment
if [ -f "$BACKEND_DIR/.env" ]; then
    export $(grep -v '^#' "$BACKEND_DIR/.env" | xargs)
fi

# Default values
BACKEND_URL=${BACKEND_URL:-http://localhost:8001}
REDIS_URL=${REDIS_URL:-redis://localhost:6379/0}

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Health Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check Docker services
echo -e "${BLUE}🐳 Checking Docker services...${NC}"
services=("mvp-backend" "mvp-celery-worker" "mvp-celery-beat" "mvp-redis")
all_healthy=true

for service in "${services[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        status=$(docker inspect --format='{{.State.Status}}' "$service")
        if [ "$status" = "running" ]; then
            echo -e "${GREEN}✅ $service is running${NC}"
        else
            echo -e "${RED}❌ $service is $status${NC}"
            all_healthy=false
        fi
    else
        echo -e "${RED}❌ $service is not running${NC}"
        all_healthy=false
    fi
done

# Check FastAPI health endpoint
echo ""
echo -e "${BLUE}🌐 Checking FastAPI health endpoint...${NC}"
if curl -f -s "$BACKEND_URL/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ FastAPI is healthy${NC}"
else
    echo -e "${RED}❌ FastAPI health check failed${NC}"
    all_healthy=false
fi

# Check Redis
echo ""
echo -e "${BLUE}🔴 Checking Redis...${NC}"
if command -v redis-cli &> /dev/null; then
    # Extract host and port from REDIS_URL
    redis_host=$(echo "$REDIS_URL" | sed -n 's|redis://\([^:]*\):\([^/]*\)/.*|\1|p' || echo "localhost")
    redis_port=$(echo "$REDIS_URL" | sed -n 's|redis://[^:]*:\([^/]*\)/.*|\1|p' || echo "6379")
    
    if redis-cli -h "$redis_host" -p "$redis_port" ping > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Redis is responding${NC}"
    else
        echo -e "${RED}❌ Redis is not responding${NC}"
        all_healthy=false
    fi
else
    # Try via Docker
    if docker exec mvp-redis redis-cli ping > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Redis is responding${NC}"
    else
        echo -e "${RED}❌ Redis is not responding${NC}"
        all_healthy=false
    fi
fi

# Check Celery workers
echo ""
echo -e "${BLUE}⚙️  Checking Celery workers...${NC}"
if docker exec mvp-celery-worker celery -A app.celery_app inspect active > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Celery worker is active${NC}"
else
    echo -e "${YELLOW}⚠️  Could not verify Celery worker status${NC}"
fi

# Summary
echo ""
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✅ All services are healthy!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}   ❌ Some services are not healthy${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    exit 1
fi
