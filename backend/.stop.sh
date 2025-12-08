#!/bin/bash
# Stop all backend services
# Usage: ./stop.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="$SCRIPT_DIR/.pids"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Stopping MVP Backend Services${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Function to stop a service
stop_service() {
    local name=$1
    local pid_file="$PID_DIR/${name}.pid"
    
    if [ ! -f "$pid_file" ]; then
        echo -e "${YELLOW}⚠️  $name is not running (no PID file)${NC}"
        return 0
    fi
    
    local pid=$(cat "$pid_file")
    
    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${BLUE}🛑 Stopping $name (PID: $pid)...${NC}"
        kill "$pid" 2>/dev/null || true
        
        # Wait for process to stop (max 5 seconds)
        local count=0
        while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
            sleep 0.5
            count=$((count + 1))
        done
        
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}⚠️  Force killing $name...${NC}"
            kill -9 "$pid" 2>/dev/null || true
        fi
        
        echo -e "${GREEN}✅ $name stopped${NC}"
    else
        echo -e "${YELLOW}⚠️  $name process not found (PID: $pid)${NC}"
    fi
    
    rm -f "$pid_file"
}

# Stop all services
stop_service "gmail-subscriber"
stop_service "celery-beat"
stop_service "celery-worker"
stop_service "backend"

# Stop Redis if we started it
if [ -f "$PID_DIR/redis.pid" ]; then
    local redis_pid=$(cat "$PID_DIR/redis.pid")
    if kill -0 "$redis_pid" 2>/dev/null; then
        echo -e "${BLUE}🛑 Stopping Redis (PID: $redis_pid)...${NC}"
        kill "$redis_pid" 2>/dev/null || true
        sleep 1
        if kill -0 "$redis_pid" 2>/dev/null; then
            kill -9 "$redis_pid" 2>/dev/null || true
        fi
        echo -e "${GREEN}✅ Redis stopped${NC}"
    fi
    rm -f "$PID_DIR/redis.pid"
fi

echo ""
echo -e "${GREEN}✅ All services stopped!${NC}"
echo ""

