#!/bin/bash
# Interactive setup for cloud backup (Google Drive or OneDrive)

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Cloud Backup Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if rclone is installed
if ! command -v rclone &> /dev/null; then
    echo -e "${YELLOW}⚠️  rclone not found. Installing...${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux installation
        curl https://rclone.org/install.sh | sudo bash
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS installation
        if command -v brew &> /dev/null; then
            brew install rclone
        else
            echo -e "${RED}❌ Please install rclone manually: https://rclone.org/install/${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Unsupported OS. Please install rclone manually.${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}📦 Choose cloud storage provider:${NC}"
echo "  1) Google Drive"
echo "  2) OneDrive"
read -p "Enter choice (1 or 2): " choice

case $choice in
    1)
        REMOTE_NAME="gdrive"
        REMOTE_TYPE="drive"
        ;;
    2)
        REMOTE_NAME="onedrive"
        REMOTE_TYPE="onedrive"
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}🔧 Configuring rclone remote: $REMOTE_NAME${NC}"
echo -e "${YELLOW}📝 Follow the interactive prompts to authenticate${NC}"
echo ""

# Configure rclone
rclone config create "$REMOTE_NAME" "$REMOTE_TYPE" config_is_local false

# Test connection
echo ""
echo -e "${BLUE}🧪 Testing connection...${NC}"
if rclone lsd "${REMOTE_NAME}:" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Connection successful!${NC}"
else
    echo -e "${RED}❌ Connection failed${NC}"
    echo -e "${BLUE}📝 Please run 'rclone config' manually to fix the configuration${NC}"
    exit 1
fi

# Create backup directory
BACKUP_DIR="mvp-backups"
echo ""
echo -e "${BLUE}📁 Creating backup directory: $BACKUP_DIR${NC}"
rclone mkdir "${REMOTE_NAME}:${BACKUP_DIR}" 2>/dev/null || echo -e "${GREEN}✅ Directory already exists${NC}"

# Update .env file
ENV_FILE="$BACKEND_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    # Check if variables already exist
    if grep -q "CLOUD_STORAGE=" "$ENV_FILE"; then
        sed -i.bak "s|^CLOUD_STORAGE=.*|CLOUD_STORAGE=$REMOTE_NAME|" "$ENV_FILE"
        rm -f "$ENV_FILE.bak"
    else
        echo "" >> "$ENV_FILE"
        echo "# Cloud Backup Configuration" >> "$ENV_FILE"
        echo "CLOUD_STORAGE=$REMOTE_NAME" >> "$ENV_FILE"
        echo "CLOUD_REMOTE=${REMOTE_NAME}:${BACKUP_DIR}" >> "$ENV_FILE"
    fi
    echo -e "${GREEN}✅ Updated .env file${NC}"
fi

# Optional: GPG encryption setup
echo ""
read -p "Do you want to set up GPG encryption for backups? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v gpg &> /dev/null; then
        echo -e "${BLUE}🔐 GPG Encryption Setup${NC}"
        echo -e "${YELLOW}📝 List of available GPG keys:${NC}"
        gpg --list-keys --keyid-format LONG | grep -E "^pub|^uid" || echo "No keys found"
        echo ""
        read -p "Enter GPG key ID or email for encryption: " gpg_recipient
        
        if [ -n "$gpg_recipient" ]; then
            # Test encryption
            echo "test" | gpg --encrypt --recipient "$gpg_recipient" > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                if grep -q "GPG_RECIPIENT=" "$ENV_FILE" 2>/dev/null; then
                    sed -i.bak "s|^GPG_RECIPIENT=.*|GPG_RECIPIENT=$gpg_recipient|" "$ENV_FILE"
                    rm -f "$ENV_FILE.bak"
                else
                    echo "GPG_RECIPIENT=$gpg_recipient" >> "$ENV_FILE"
                fi
                echo -e "${GREEN}✅ GPG encryption configured${NC}"
            else
                echo -e "${RED}❌ Invalid GPG key${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  GPG not installed${NC}"
    fi
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✅ Cloud backup setup complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📋 Configuration:${NC}"
echo "  - Remote name: $REMOTE_NAME"
echo "  - Backup directory: $BACKUP_DIR"
echo "  - Test backup: $SCRIPT_DIR/backup.sh"
echo ""
