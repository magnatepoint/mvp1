#!/bin/bash
# Start all backend services: Redis, FastAPI, Celery Worker, Celery Beat, Gmail Pub/Sub
# Usage: ./start.sh [--detach] [--no-redis] [--no-gmail]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse arguments
DETACH=false
NO_REDIS=false
NO_GMAIL=false

for arg in "$@"; do
    case $arg in
        --detach)
            DETACH=true
            shift
            ;;
        --no-redis)
            NO_REDIS=true
            shift
            ;;
        --no-gmail)
            NO_GMAIL=true
            shift
            ;;
        *)
            ;;
    esac
done

# PID file directory
PID_DIR="$SCRIPT_DIR/.pids"
mkdir -p "$PID_DIR"

# Function to check if a process is running
is_running() {
    local pid=$1
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to start a service in background
start_service() {
    local name=$1
    local cmd=$2
    local pid_file="$PID_DIR/${name}.pid"
    
    # Check if already running
    if [ -f "$pid_file" ]; then
        local old_pid=$(cat "$pid_file")
        if is_running "$old_pid"; then
            echo -e "${YELLOW}⚠️  $name is already running (PID: $old_pid)${NC}"
            return 1
        else
            rm -f "$pid_file"
        fi
    fi
    
    echo -e "${BLUE}🚀 Starting $name...${NC}"
    
    if [ "$DETACH" = true ]; then
        # Run in background, redirect output to log file
        eval "$cmd" > "$PID_DIR/${name}.log" 2>&1 &
        local pid=$!
        echo $pid > "$pid_file"
        echo -e "${GREEN}✅ $name started (PID: $pid)${NC}"
    else
        # Run in background but keep in same process group
        eval "$cmd" > "$PID_DIR/${name}.log" 2>&1 &
        local pid=$!
        echo $pid > "$pid_file"
        echo -e "${GREEN}✅ $name started (PID: $pid)${NC}"
    fi
    
    # Wait a moment to check if it started successfully
    sleep 1
    if ! is_running "$pid"; then
        echo -e "${RED}❌ $name failed to start. Check logs: $PID_DIR/${name}.log${NC}"
        rm -f "$pid_file"
        return 1
    fi
}

# Check if virtual environment exists
if [ -d ".venv" ]; then
    echo -e "${BLUE}📦 Activating virtual environment...${NC}"
    source .venv/bin/activate
elif [ -d "venv" ]; then
    echo -e "${BLUE}📦 Activating virtual environment...${NC}"
    source venv/bin/activate
else
    echo -e "${YELLOW}⚠️  No virtual environment found. Make sure dependencies are installed.${NC}"
fi

# Set PYTHONPATH
export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Starting MVP Backend Services${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# 1. Start Redis (if not disabled)
if [ "$NO_REDIS" = false ]; then
    if command -v redis-server &> /dev/null; then
        # Check if Redis is already running
        if command -v redis-cli &> /dev/null && redis-cli ping &> /dev/null 2>&1; then
            echo -e "${GREEN}✅ Redis is already running${NC}"
        else
            echo -e "${BLUE}🚀 Starting Redis...${NC}"
            if [ "$DETACH" = true ]; then
                redis-server --daemonize yes --pidfile "$PID_DIR/redis.pid"
            else
                start_service "redis" "redis-server"
            fi
            sleep 2
            if command -v redis-cli &> /dev/null && redis-cli ping &> /dev/null 2>&1; then
                echo -e "${GREEN}✅ Redis started successfully${NC}"
            else
                echo -e "${YELLOW}⚠️  Redis may have started but ping failed. Continuing...${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  redis-server not found. Skipping Redis startup.${NC}"
        echo -e "${YELLOW}   Make sure Redis is running on redis://localhost:6379${NC}"
    fi
else
    echo -e "${YELLOW}⏭️  Skipping Redis (--no-redis flag)${NC}"
fi

# 2. Start FastAPI Backend
echo ""
start_service "backend" "uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"

# 3. Start Celery Worker
echo ""
start_service "celery-worker" "celery -A app.celery_app worker --loglevel=info --concurrency=4"

# 4. Start Celery Beat
echo ""
start_service "celery-beat" "celery -A app.celery_app beat --loglevel=info"

# 5. Start Gmail Pub/Sub Subscriber (if not disabled)
if [ "$NO_GMAIL" = false ]; then
    echo ""
    start_service "gmail-subscriber" "python3 -m app.gmail.subscriber"
else
    echo -e "${YELLOW}⏭️  Skipping Gmail Pub/Sub Subscriber (--no-gmail flag)${NC}"
fi

# Note: Realtime subscriber is started automatically in main.py startup event

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All services started!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Services:${NC}"
echo -e "  • Backend API:     ${GREEN}http://localhost:8000${NC}"
echo -e "  • API Docs:        ${GREEN}http://localhost:8000/docs${NC}"
echo -e "  • Redis:           ${GREEN}redis://localhost:6379${NC}"
echo -e "  • Celery Worker:   ${GREEN}Running${NC}"
echo -e "  • Celery Beat:     ${GREEN}Running${NC}"
if [ "$NO_GMAIL" = false ]; then
    echo -e "  • Gmail Subscriber: ${GREEN}Running${NC}"
fi
echo -e "  • Realtime:        ${GREEN}Started with backend${NC}"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo -e "  • PID files:       ${YELLOW}$PID_DIR/*.pid${NC}"
echo -e "  • Log files:       ${YELLOW}$PID_DIR/*.log${NC}"
echo ""
echo -e "${BLUE}To stop all services:${NC}"
echo -e "  ${YELLOW}./stop.sh${NC} or ${YELLOW}kill \$(cat $PID_DIR/*.pid)${NC}"
echo ""

# If not detached, wait for user interrupt
if [ "$DETACH" = false ]; then
    echo -e "${BLUE}Press Ctrl+C to stop all services...${NC}"
    echo ""
    
    # Trap Ctrl+C to stop all services
    trap 'echo ""; echo -e "${YELLOW}Stopping all services...${NC}"; "$SCRIPT_DIR/.stop.sh"; exit 0' INT TERM
    
    # Wait for all background processes
    wait
fi

