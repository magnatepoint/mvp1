#!/bin/bash
# Install systemd services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"
SYSTEMD_DIR="$DEPLOY_DIR/systemd"
SERVICES_DIR="/etc/systemd/system"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Installing Systemd Services${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    exit 1
fi

# Install services
for service_file in "$SYSTEMD_DIR"/*.service; do
    if [ -f "$service_file" ]; then
        service_name=$(basename "$service_file")
        echo -e "${BLUE}📦 Installing $service_name...${NC}"
        cp "$service_file" "$SERVICES_DIR/$service_name"
        chmod 644 "$SERVICES_DIR/$service_name"
        systemctl daemon-reload
        systemctl enable "$service_name"
        echo -e "${GREEN}✅ Installed and enabled $service_name${NC}"
    fi
done

# Install timers
for timer_file in "$SYSTEMD_DIR"/*.timer; do
    if [ -f "$timer_file" ]; then
        timer_name=$(basename "$timer_file")
        echo -e "${BLUE}📦 Installing $timer_name...${NC}"
        cp "$timer_file" "$SERVICES_DIR/$timer_name"
        chmod 644 "$SERVICES_DIR/$timer_name"
        systemctl daemon-reload
        systemctl enable "$timer_name"
        systemctl start "$timer_name"
        echo -e "${GREEN}✅ Installed and started $timer_name${NC}"
    fi
done

echo ""
echo -e "${GREEN}✅ All services installed!${NC}"
echo ""
echo -e "${BLUE}📋 Available services:${NC}"
echo "  - backend.service"
echo "  - cloudflare-tunnel.service"
echo "  - backup.service (runs via backup.timer)"
echo ""
echo -e "${BLUE}📝 Commands:${NC}"
echo "  sudo systemctl start backend"
echo "  sudo systemctl status backend"
echo "  sudo systemctl stop backend"
