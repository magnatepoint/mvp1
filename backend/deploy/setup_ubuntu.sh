#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Ubuntu Server Setup for MVP Backend${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./setup_ubuntu.sh)"
  exit 1
fi

echo -e "${BLUE}🔄 Updating system packages...${NC}"
apt-get update && apt-get upgrade -y

echo -e "${BLUE}📦 Installing prerequisites...${NC}"
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    git \
    lsb-release

# Install Docker
if ! command -v docker &> /dev/null; then
    echo -e "${BLUE}🐳 Installing Docker...${NC}"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
else
    echo -e "${GREEN}✅ Docker is already installed.${NC}"
fi

# Enable Docker service
systemctl enable docker
systemctl start docker

# Create project directory
PROJECT_DIR="/opt/mvp-backend"
echo -e "${BLUE}📂 Creating project directory at ${PROJECT_DIR}...${NC}"
mkdir -p "$PROJECT_DIR"

# Set permissions (assuming standard ubuntu user or similar, adjust if needed)
# If a specific user is passed as an argument, use it. Otherwise default to current SUDO_USER or 'ubuntu'
TARGET_USER="${1:-$SUDO_USER}"
if [ -z "$TARGET_USER" ]; then
    TARGET_USER="ubuntu"
    if ! id "$TARGET_USER" &>/dev/null; then
        echo "User 'ubuntu' not found, defaulting to 'root'"
        TARGET_USER="root"
    fi
fi

echo -e "${BLUE}bust Setting ownership to user: ${TARGET_USER}${NC}"
chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR"
chmod -R 775 "$PROJECT_DIR"

# Add user to docker group
if ! groups "$TARGET_USER" | grep -q "docker"; then
    echo -e "${BLUE}👤 Adding ${TARGET_USER} to docker group...${NC}"
    usermod -aG docker "$TARGET_USER"
    echo -e "${GREEN}User added to docker group. You may need to logout and login again.${NC}"
fi

echo ""
echo -e "${GREEN}✅ Server setup complete!${NC}"
echo -e "Next steps:"
echo -e "1. Copy your .env file to ${PROJECT_DIR}/backend/.env"
echo -e "2. Clone/Copy your repository to ${PROJECT_DIR}"
echo -e "3. Run manual-deploy.sh"
