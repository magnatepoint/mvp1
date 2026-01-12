#!/bin/bash
# Fix port 8000 conflict

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Port 8000 Conflict Fix${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check what's using port 8000
echo -e "${BLUE}🔍 Checking what's using port 8000...${NC}"

# Check Docker containers
if docker ps --format '{{.Names}}\t{{.Ports}}' | grep -q ":8000"; then
    echo -e "${YELLOW}⚠️  Found Docker container using port 8000:${NC}"
    docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep ":8000"
    echo ""
    read -p "Stop these containers? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker ps --format '{{.Names}}' | grep -E "(mvp|backend)" | xargs docker stop 2>/dev/null || true
        echo -e "${GREEN}✅ Stopped containers${NC}"
    fi
fi

# Check system processes
if command -v lsof &> /dev/null; then
    PID=$(lsof -ti:8000 2>/dev/null || echo "")
    if [ -n "$PID" ]; then
        echo -e "${YELLOW}⚠️  Found process using port 8000:${NC}"
        ps -p $PID -o pid,user,cmd
        echo ""
        read -p "Kill this process? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill $PID 2>/dev/null || sudo kill $PID
            echo -e "${GREEN}✅ Killed process${NC}"
        fi
    fi
elif command -v netstat &> /dev/null; then
    PID=$(netstat -tlnp 2>/dev/null | grep :8000 | awk '{print $7}' | cut -d'/' -f1 | head -1)
    if [ -n "$PID" ]; then
        echo -e "${YELLOW}⚠️  Found process using port 8000 (PID: $PID)${NC}"
        ps -p $PID -o pid,user,cmd 2>/dev/null || echo "Process info not available"
        echo ""
        read -p "Kill this process? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill $PID 2>/dev/null || sudo kill $PID
            echo -e "${GREEN}✅ Killed process${NC}"
        fi
    fi
fi

# Check for old Docker containers
echo ""
echo -e "${BLUE}🔍 Checking for stopped containers...${NC}"
if docker ps -a --format '{{.Names}}' | grep -qE "(mvp|backend)"; then
    echo -e "${YELLOW}Found stopped containers:${NC}"
    docker ps -a --format 'table {{.Names}}\t{{.Status}}' | grep -E "(mvp|backend)"
    echo ""
    read -p "Remove these containers? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker ps -a --format '{{.Names}}' | grep -E "(mvp|backend)" | xargs docker rm 2>/dev/null || true
        echo -e "${GREEN}✅ Removed containers${NC}"
    fi
fi

# Final check
echo ""
echo -e "${BLUE}🔍 Final port check...${NC}"
if lsof -ti:8000 > /dev/null 2>&1 || netstat -tlnp 2>/dev/null | grep -q :8000; then
    echo -e "${RED}❌ Port 8000 is still in use${NC}"
    echo -e "${YELLOW}Please manually stop the process or use a different port${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Port 8000 is now free${NC}"
fi

echo ""
echo -e "${GREEN}✅ Ready to deploy!${NC}"
echo -e "${BLUE}Run: docker-compose up -d${NC}"
