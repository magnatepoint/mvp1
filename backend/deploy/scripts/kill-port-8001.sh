#!/bin/bash
# Force kill whatever is using port 8001

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Finding what's using port 8001...${NC}"
echo ""

# Method 1: Using lsof
if command -v lsof &> /dev/null; then
    PIDS=$(lsof -ti:8001 2>/dev/null || echo "")
    if [ -n "$PIDS" ]; then
        echo -e "${YELLOW}Found processes using port 8001:${NC}"
        for PID in $PIDS; do
            ps -p $PID -o pid,user,cmd 2>/dev/null || echo "PID: $PID"
        done
        echo ""
        echo -e "${RED}Killing processes...${NC}"
        echo $PIDS | xargs kill -9 2>/dev/null || echo $PIDS | xargs sudo kill -9
        sleep 2
    fi
fi

# Method 2: Using netstat
if [ -z "$PIDS" ] && command -v netstat &> /dev/null; then
    PID=$(netstat -tlnp 2>/dev/null | grep :8001 | awk '{print $7}' | cut -d'/' -f1 | head -1)
    if [ -n "$PID" ] && [ "$PID" != "-" ]; then
        echo -e "${YELLOW}Found process using port 8001 (PID: $PID)${NC}"
        ps -p $PID -o pid,user,cmd 2>/dev/null || echo "Process info not available"
        echo ""
        echo -e "${RED}Killing process...${NC}"
        kill -9 $PID 2>/dev/null || sudo kill -9 $PID
        sleep 2
    fi
fi

# Method 3: Using ss
if [ -z "$PIDS" ] && command -v ss &> /dev/null; then
    PID=$(ss -tlnp 2>/dev/null | grep :8001 | grep -oP 'pid=\K[0-9]+' | head -1)
    if [ -n "$PID" ]; then
        echo -e "${YELLOW}Found process using port 8001 (PID: $PID)${NC}"
        ps -p $PID -o pid,user,cmd 2>/dev/null || echo "Process info not available"
        echo ""
        echo -e "${RED}Killing process...${NC}"
        kill -9 $PID 2>/dev/null || sudo kill -9 $PID
        sleep 2
    fi
fi

# Check Docker containers
echo ""
echo -e "${BLUE}🔍 Checking Docker containers...${NC}"
if docker ps --format '{{.Names}}' | grep -qE "(mvp|backend|8001)"; then
    echo -e "${YELLOW}Found Docker containers:${NC}"
    docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep -E "(mvp|backend|8001)"
    echo ""
    echo -e "${RED}Stopping containers...${NC}"
    docker ps --format '{{.Names}}' | grep -E "(mvp|backend)" | xargs docker stop 2>/dev/null || true
    docker ps -a --format '{{.Names}}' | grep -E "(mvp|backend)" | xargs docker rm 2>/dev/null || true
    sleep 2
fi

# Final check
echo ""
echo -e "${BLUE}🔍 Final check...${NC}"
if lsof -ti:8001 > /dev/null 2>&1 || (command -v netstat &> /dev/null && netstat -tlnp 2>/dev/null | grep -q :8001); then
    echo -e "${RED}❌ Port 8001 is still in use${NC}"
    echo -e "${YELLOW}Try running with sudo:${NC}"
    echo "  sudo ./deploy/scripts/kill-port-8001.sh"
    exit 1
else
    echo -e "${GREEN}✅ Port 8001 is now free!${NC}"
fi

echo ""
echo -e "${GREEN}✅ Ready to deploy!${NC}"
