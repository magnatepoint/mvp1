#!/bin/bash
# Initial server setup script for Ubuntu

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Ubuntu Server Setup for MVP Backend${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Update system
echo -e "${BLUE}📦 Updating system packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install required packages
echo -e "${BLUE}📦 Installing required packages...${NC}"
apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    postgresql-client \
    redis-tools \
    ufw \
    gnupg2 \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    lsb-release

# Install Docker
echo -e "${BLUE}🐳 Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    usermod -aG docker $SUDO_USER
    echo -e "${GREEN}✅ Docker installed${NC}"
else
    echo -e "${GREEN}✅ Docker already installed${NC}"
fi

# Install Docker Compose
echo -e "${BLUE}🐳 Installing Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✅ Docker Compose installed${NC}"
else
    echo -e "${GREEN}✅ Docker Compose already installed${NC}"
fi

# Install rclone (for cloud backups)
echo -e "${BLUE}☁️  Installing rclone...${NC}"
if ! command -v rclone &> /dev/null; then
    curl https://rclone.org/install.sh | bash
    echo -e "${GREEN}✅ rclone installed${NC}"
else
    echo -e "${GREEN}✅ rclone already installed${NC}"
fi

# Install cloudflared (for Cloudflare Tunnel)
echo -e "${BLUE}🌐 Installing cloudflared...${NC}"
if ! command -v cloudflared &> /dev/null; then
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
    echo -e "${GREEN}✅ cloudflared installed${NC}"
else
    echo -e "${GREEN}✅ cloudflared already installed${NC}"
fi

# Configure firewall
echo -e "${BLUE}🔥 Configuring firewall (UFW)...${NC}"
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 22/tcp
# Note: We don't open ports 80/443 because Cloudflare Tunnel handles routing
echo -e "${GREEN}✅ Firewall configured${NC}"

# Create application directory
APP_DIR="/opt/mvp-backend"
echo -e "${BLUE}📁 Creating application directory: $APP_DIR${NC}"
mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/logs"
mkdir -p "$APP_DIR/data"
mkdir -p "$APP_DIR/backups"
chown -R $SUDO_USER:$SUDO_USER "$APP_DIR"
echo -e "${GREEN}✅ Application directory created${NC}"

# Set up log rotation
echo -e "${BLUE}📋 Setting up log rotation...${NC}"
cat > /etc/logrotate.d/mvp-backend <<EOF
$APP_DIR/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 $SUDO_USER $SUDO_USER
}
EOF
echo -e "${GREEN}✅ Log rotation configured${NC}"

# Create systemd directories
mkdir -p /etc/systemd/system

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✅ Server setup complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "  1. Clone your repository to $APP_DIR"
echo "  2. Copy .env file to $APP_DIR/.env"
echo "  3. Run: cd $APP_DIR && ./deploy/scripts/setup-cloudflare-tunnel.sh"
echo "  4. Run: cd $APP_DIR && ./deploy/scripts/setup-cloud-backup.sh"
echo "  5. Run: cd $APP_DIR && ./deploy/deploy.sh"
echo ""
echo -e "${YELLOW}⚠️  Note: You may need to log out and back in for Docker group changes to take effect${NC}"
