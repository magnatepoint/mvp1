#!/bin/bash
# Diagnostic script for Cloudflare Tunnel issues

set -e

echo "🔍 Cloudflare Tunnel Diagnostic Script"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check if cloudflared container is running
echo "1. Checking cloudflared container status..."
if docker ps | grep -q cloudflared; then
    echo -e "${GREEN}✅ Cloudflared container is running${NC}"
    CONTAINER_ID=$(docker ps | grep cloudflared | awk '{print $1}')
    CONTAINER_NAME=$(docker ps | grep cloudflared | awk '{print $NF}')
    echo "   Container ID: $CONTAINER_ID"
    echo "   Container Name: $CONTAINER_NAME"
else
    echo -e "${RED}❌ Cloudflared container is NOT running${NC}"
    exit 1
fi

echo ""

# 2. Check container logs
echo "2. Checking cloudflared container logs (last 50 lines)..."
echo "   ---"
docker logs --tail 50 "$CONTAINER_NAME" 2>&1 | head -30
echo "   ---"

echo ""

# 3. Check if backend is accessible from container
echo "3. Testing backend connectivity from tunnel container..."
if docker exec "$CONTAINER_NAME" curl -s -f http://host.docker.internal:8001/health > /dev/null 2>&1 || \
   docker exec "$CONTAINER_NAME" curl -s -f http://172.17.0.1:8001/health > /dev/null 2>&1 || \
   docker exec "$CONTAINER_NAME" curl -s -f http://localhost:8001/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend is accessible from tunnel container${NC}"
else
    echo -e "${YELLOW}⚠️  Backend might not be accessible from tunnel container${NC}"
    echo "   Trying different host addresses..."
    for host in host.docker.internal 172.17.0.1 localhost; do
        echo "   Testing http://$host:8001/health..."
        docker exec "$CONTAINER_NAME" curl -s -f "http://$host:8001/health" && echo -e "   ${GREEN}✅ $host works${NC}" || echo -e "   ${RED}❌ $host failed${NC}"
    done
fi

echo ""

# 4. Check backend container
echo "4. Checking backend container..."
if docker ps | grep -q mvp-backend; then
    echo -e "${GREEN}✅ Backend container is running${NC}"
    BACKEND_CONTAINER=$(docker ps | grep mvp-backend | awk '{print $NF}')
    echo "   Container: $BACKEND_CONTAINER"
    
    # Test backend health
    if docker exec "$BACKEND_CONTAINER" curl -s -f http://localhost:8001/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Backend health check passed${NC}"
    else
        echo -e "${RED}❌ Backend health check failed${NC}"
    fi
else
    echo -e "${RED}❌ Backend container is NOT running${NC}"
fi

echo ""

# 5. Test external API access
echo "5. Testing external API access..."
if curl -s -f https://api.monytix.ai/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ API is accessible externally${NC}"
    curl -s https://api.monytix.ai/health | head -1
else
    echo -e "${RED}❌ API is NOT accessible externally${NC}"
    echo "   Error details:"
    curl -v https://api.monytix.ai/health 2>&1 | grep -E "(error|Error|HTTP|hostname)" | head -5
fi

echo ""

# 6. Check DNS
echo "6. Checking DNS resolution for api.monytix.ai..."
DNS_RESULT=$(dig +short api.monytix.ai 2>/dev/null || echo "DNS lookup failed")
if [ -n "$DNS_RESULT" ] && [ "$DNS_RESULT" != "DNS lookup failed" ]; then
    echo -e "${GREEN}✅ DNS resolves: $DNS_RESULT${NC}"
else
    echo -e "${RED}❌ DNS resolution failed${NC}"
fi

echo ""

# 7. Check tunnel configuration (if accessible)
echo "7. Checking tunnel configuration..."
if docker exec "$CONTAINER_NAME" cat /etc/cloudflared/config.yml > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Config file accessible${NC}"
    echo "   Configuration:"
    docker exec "$CONTAINER_NAME" cat /etc/cloudflared/config.yml 2>/dev/null | grep -E "(tunnel|hostname|service)" || echo "   Could not read config"
else
    echo -e "${YELLOW}⚠️  Config file not accessible in container${NC}"
fi

echo ""

# 8. Recommendations
echo "📋 Recommendations:"
echo "===================="
echo ""
echo "If API is not accessible:"
echo "1. Check Cloudflare Dashboard → Zero Trust → Tunnels"
echo "2. Verify tunnel 'mvp-backend-tunnel' is active and connected"
echo "3. Verify DNS CNAME record: api.monytix.ai → <tunnel-hostname>"
echo "4. Check tunnel logs for connection errors:"
echo "   docker logs $CONTAINER_NAME --tail 100"
echo ""
echo "If backend is not accessible from tunnel:"
echo "1. Ensure backend container is on same Docker network"
echo "2. Use 'host.docker.internal' or Docker network IP"
echo "3. Verify backend is listening on 0.0.0.0:8001"
echo ""
