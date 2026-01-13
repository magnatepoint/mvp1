#!/bin/bash
# Complete installation script for fresh Ubuntu server
# Usage: curl -fsSL https://raw.githubusercontent.com/your-repo/main/backend/deploy/install-fresh-server.sh | bash
# Or: wget -qO- https://raw.githubusercontent.com/your-repo/main/backend/deploy/install-fresh-server.sh | bash

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "   MVP Backend - Fresh Ubuntu Server Installation"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}❌ Please do not run as root. Run as a regular user with sudo privileges.${NC}"
   exit 1
fi

# Configuration
INSTALL_DIR="/opt/mvp-backend"
REPO_URL="https://github.com/magnatepoint/mvp1.git"
BACKEND_DIR="$INSTALL_DIR/backend"

echo -e "${BLUE}📋 Installation Steps:${NC}"
echo "   1. Update system packages"
echo "   2. Install Docker and Docker Compose"
echo "   3. Install Git and other dependencies"
echo "   4. Clone repository"
echo "   5. Set up environment variables"
echo "   6. Configure Cloudflare Tunnel (optional)"
echo "   7. Start services"
echo ""

read -p "Press Enter to continue or Ctrl+C to cancel..."

# Step 1: Update system
echo ""
echo -e "${BLUE}📦 Step 1: Updating system packages...${NC}"
sudo apt-get update
sudo apt-get upgrade -y

# Step 2: Install dependencies
echo ""
echo -e "${BLUE}📦 Step 2: Installing dependencies...${NC}"
sudo apt-get install -y \
    curl \
    wget \
    git \
    nano \
    ufw \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Step 3: Install Docker
echo ""
echo -e "${BLUE}🐳 Step 3: Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    echo -e "${GREEN}✅ Docker installed${NC}"
    echo -e "${YELLOW}⚠️  You may need to log out and back in for Docker group changes to take effect${NC}"
else
    echo -e "${GREEN}✅ Docker already installed${NC}"
fi

# Step 4: Install Docker Compose (standalone if not using plugin)
if ! docker compose version &> /dev/null; then
    echo ""
    echo -e "${BLUE}📦 Installing Docker Compose standalone...${NC}"
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✅ Docker Compose installed${NC}"
else
    echo -e "${GREEN}✅ Docker Compose already available${NC}"
fi

# Step 5: Create installation directory
echo ""
echo -e "${BLUE}📁 Step 4: Setting up directories...${NC}"
sudo mkdir -p $INSTALL_DIR
sudo chown $USER:$USER $INSTALL_DIR

# Step 6: Clone repository
echo ""
echo -e "${BLUE}📥 Step 5: Cloning repository...${NC}"
if [ -d "$BACKEND_DIR" ]; then
    echo -e "${YELLOW}⚠️  Directory $BACKEND_DIR already exists${NC}"
    read -p "Do you want to remove it and clone fresh? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo rm -rf $BACKEND_DIR
        git clone $REPO_URL $INSTALL_DIR
    else
        echo -e "${BLUE}📥 Pulling latest changes...${NC}"
        cd $BACKEND_DIR
        git pull origin main
    fi
else
    git clone $REPO_URL $INSTALL_DIR
fi

cd $BACKEND_DIR

# Step 7: Set up environment file
echo ""
echo -e "${BLUE}⚙️  Step 6: Setting up environment variables...${NC}"
if [ ! -f "$BACKEND_DIR/.env" ]; then
    echo -e "${YELLOW}📝 Creating .env file...${NC}"
    echo ""
    echo "You need to create a .env file with your configuration."
    echo "A template will be created. Please edit it with your values:"
    echo ""
    
    cat > $BACKEND_DIR/.env << 'EOF'
# Environment
ENVIRONMENT=production
LOG_LEVEL=INFO
WORKERS=2

# MongoDB
MONGODB_URI=mongodb+srv://user:password@cluster.mongodb.net/
MONGODB_DB_NAME=monytix_rawdata

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_JWT_SECRET=your-jwt-secret
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# PostgreSQL (uses Supabase connection string)
POSTGRES_URL=postgresql://postgres.user:password@host:port/database

# Redis
REDIS_URL=redis://localhost:6379/0

# Gmail API
GMAIL_CLIENT_ID=your-client-id
GMAIL_CLIENT_SECRET=your-client-secret
GMAIL_REDIRECT_URI=http://localhost:8001/gmail/oauth/callback

# Frontend
FRONTEND_ORIGIN=https://mvp.monytix.ai

# Application Port (host port mapping)
APP_PORT=8001
EOF
    
    echo -e "${YELLOW}⚠️  Please edit $BACKEND_DIR/.env with your actual values${NC}"
    echo ""
    read -p "Press Enter after you've edited the .env file..."
else
    echo -e "${GREEN}✅ .env file already exists${NC}"
fi

# Step 8: Install Cloudflare Tunnel (optional)
echo ""
echo -e "${BLUE}🌐 Step 7: Cloudflare Tunnel setup (optional)...${NC}"
read -p "Do you want to set up Cloudflare Tunnel now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! command -v cloudflared &> /dev/null; then
        echo "Installing cloudflared..."
        curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
        sudo dpkg -i /tmp/cloudflared.deb
        rm /tmp/cloudflared.deb
    fi
    
    echo "Setting up Cloudflare Tunnel..."
    cd $BACKEND_DIR
    chmod +x deploy/scripts/setup-cloudflare-tunnel.sh
    ./deploy/scripts/setup-cloudflare-tunnel.sh
else
    echo -e "${YELLOW}⏭️  Skipping Cloudflare Tunnel setup${NC}"
fi

# Step 9: Configure firewall
echo ""
echo -e "${BLUE}🔥 Step 8: Configuring firewall...${NC}"
if sudo ufw status | grep -q "Status: active"; then
    echo -e "${GREEN}✅ UFW is already active${NC}"
else
    echo "Setting up UFW firewall..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 8001/tcp  # Backend port
    echo "Enabling UFW..."
    echo "y" | sudo ufw enable
    echo -e "${GREEN}✅ Firewall configured${NC}"
fi

# Step 10: Build and start services
echo ""
echo -e "${BLUE}🔨 Step 9: Building Docker images...${NC}"
cd $BACKEND_DIR
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

echo ""
echo -e "${BLUE}🚀 Step 10: Starting services...${NC}"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

echo ""
echo -e "${BLUE}⏳ Waiting for services to start...${NC}"
sleep 10

# Step 11: Check status
echo ""
echo -e "${BLUE}📊 Step 11: Checking service status...${NC}"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps

echo ""
echo -e "${BLUE}📋 Backend logs (last 20 lines):${NC}"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs --tail=20 backend

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✅ Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "   1. Verify .env file is configured correctly"
echo "   2. Set up Cloudflare Tunnel (if not done):"
echo "      cd $BACKEND_DIR && ./deploy/scripts/setup-cloudflare-tunnel.sh"
echo "   3. Check service logs:"
echo "      cd $BACKEND_DIR && docker-compose logs -f backend"
echo "   4. Test the API:"
echo "      curl http://localhost:8001/health"
echo ""
echo -e "${BLUE}📚 Useful Commands:${NC}"
echo "   View logs:        cd $BACKEND_DIR && docker-compose logs -f"
echo "   Restart services: cd $BACKEND_DIR && docker-compose restart"
echo "   Stop services:    cd $BACKEND_DIR && docker-compose down"
echo "   Update code:      cd $BACKEND_DIR && git pull && docker-compose build --no-cache && docker-compose up -d"
echo ""
