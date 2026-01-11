#!/bin/bash
# Complete new server deployment script (disaster recovery)

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$(dirname "$DEPLOY_DIR")"
APP_DIR="/opt/mvp-backend"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   New Server Deployment (Disaster Recovery)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Step 1: Server setup
echo -e "${BLUE}📦 Step 1: Setting up server...${NC}"
if [ -f "$DEPLOY_DIR/scripts/setup-server.sh" ]; then
    bash "$DEPLOY_DIR/scripts/setup-server.sh"
else
    echo -e "${YELLOW}⚠️  setup-server.sh not found, skipping${NC}"
fi

# Step 2: Clone or copy repository
echo ""
echo -e "${BLUE}📥 Step 2: Setting up application code...${NC}"
if [ ! -d "$APP_DIR" ]; then
    mkdir -p "$APP_DIR"
fi

read -p "Do you have the code repository? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter repository URL (or path to local directory): " repo_url
    if [ -n "$repo_url" ]; then
        if [ -d "$repo_url" ]; then
            # Local directory
            echo -e "${BLUE}📁 Copying from local directory...${NC}"
            cp -r "$repo_url"/* "$APP_DIR/" 2>/dev/null || rsync -av "$repo_url/" "$APP_DIR/"
        else
            # Git repository
            echo -e "${BLUE}📥 Cloning repository...${NC}"
            git clone "$repo_url" "$APP_DIR" || echo -e "${RED}❌ Failed to clone repository${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠️  Please copy your code to $APP_DIR manually${NC}"
    read -p "Press Enter when code is in place..."
fi

# Set ownership
chown -R $SUDO_USER:$SUDO_USER "$APP_DIR"

# Step 3: Restore from backup
echo ""
echo -e "${BLUE}💾 Step 3: Restoring from backup...${NC}"
read -p "Do you want to restore from a backup? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    if [ -f "$APP_DIR/deploy/scripts/restore.sh" ]; then
        cd "$APP_DIR"
        sudo -u $SUDO_USER bash deploy/scripts/restore.sh
    else
        echo -e "${YELLOW}⚠️  restore.sh not found${NC}"
    fi
else
    echo -e "${BLUE}📝 Please configure .env file manually${NC}"
    if [ -f "$APP_DIR/.env.production.example" ]; then
        cp "$APP_DIR/.env.production.example" "$APP_DIR/.env"
        echo -e "${GREEN}✅ Created .env from template. Please edit it:${NC}"
        echo "  nano $APP_DIR/.env"
        read -p "Press Enter when .env is configured..."
    fi
fi

# Step 4: Setup Cloudflare Tunnel
echo ""
echo -e "${BLUE}🌐 Step 4: Setting up Cloudflare Tunnel...${NC}"
read -p "Do you want to set up Cloudflare Tunnel? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    if [ -f "$APP_DIR/deploy/scripts/setup-cloudflare-tunnel.sh" ]; then
        cd "$APP_DIR"
        sudo -u $SUDO_USER bash deploy/scripts/setup-cloudflare-tunnel.sh
    else
        echo -e "${YELLOW}⚠️  setup-cloudflare-tunnel.sh not found${NC}"
    fi
fi

# Step 5: Setup cloud backup
echo ""
echo -e "${BLUE}☁️  Step 5: Setting up cloud backup...${NC}"
read -p "Do you want to set up cloud backup? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    if [ -f "$APP_DIR/deploy/scripts/setup-cloud-backup.sh" ]; then
        cd "$APP_DIR"
        sudo -u $SUDO_USER bash deploy/scripts/setup-cloud-backup.sh
    else
        echo -e "${YELLOW}⚠️  setup-cloud-backup.sh not found${NC}"
    fi
fi

# Step 6: Deploy application
echo ""
echo -e "${BLUE}🚀 Step 6: Deploying application...${NC}"
if [ -f "$APP_DIR/deploy/deploy.sh" ]; then
    cd "$APP_DIR"
    sudo -u $SUDO_USER bash deploy/deploy.sh
else
    echo -e "${YELLOW}⚠️  deploy.sh not found${NC}"
    echo -e "${BLUE}📝 Manual deployment steps:${NC}"
    echo "  1. cd $APP_DIR"
    echo "  2. docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d"
fi

# Step 7: Install systemd services
echo ""
echo -e "${BLUE}⚙️  Step 7: Installing systemd services...${NC}"
read -p "Do you want to install systemd services? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    if [ -f "$APP_DIR/deploy/scripts/install-service.sh" ]; then
        bash "$APP_DIR/deploy/scripts/install-service.sh"
    else
        echo -e "${YELLOW}⚠️  install-service.sh not found${NC}"
    fi
fi

# Final health check
echo ""
echo -e "${BLUE}🏥 Final health check...${NC}"
if [ -f "$APP_DIR/deploy/scripts/health-check.sh" ]; then
    cd "$APP_DIR"
    sudo -u $SUDO_USER bash deploy/scripts/health-check.sh || echo -e "${YELLOW}⚠️  Health check had issues${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✅ New server deployment complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "  1. Verify all services are running: docker ps"
echo "  2. Check logs: docker-compose logs -f"
echo "  3. Update DNS if needed"
echo "  4. Test the API endpoint"
echo ""
