#!/bin/bash
# Upload backup to cloud storage (Google Drive or OneDrive via rclone)

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

if [ $# -lt 1 ]; then
    echo -e "${RED}❌ Usage: $0 <backup-file>${NC}"
    exit 1
fi

BACKUP_FILE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
RCLONE_CONFIG="${RCLONE_CONFIG:-$HOME/.config/rclone/rclone.conf}"

# Load environment
if [ -f "$BACKEND_DIR/.env" ]; then
    export $(grep -v '^#' "$BACKEND_DIR/.env" | xargs)
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

# Check if rclone is installed
if ! command -v rclone &> /dev/null; then
    echo -e "${YELLOW}⚠️  rclone not found. Install it from https://rclone.org/install/${NC}"
    exit 1
fi

# Get cloud storage configuration
CLOUD_STORAGE=${CLOUD_STORAGE:-"gdrive"}
CLOUD_REMOTE=${CLOUD_REMOTE:-"${CLOUD_STORAGE}:mvp-backups"}
BACKUP_FILENAME=$(basename "$BACKUP_FILE")

echo -e "${BLUE}☁️  Uploading to $CLOUD_STORAGE...${NC}"

# Check if remote is configured
if ! rclone listremotes | grep -q "^${CLOUD_STORAGE}:"; then
    echo -e "${YELLOW}⚠️  Remote '$CLOUD_STORAGE' not configured${NC}"
    echo -e "${BLUE}📝 Please run: rclone config${NC}"
    echo -e "${BLUE}   Or run: $SCRIPT_DIR/setup-cloud-backup.sh${NC}"
    exit 1
fi

# Test connection
if ! rclone lsd "$CLOUD_STORAGE:" > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to $CLOUD_STORAGE${NC}"
    echo -e "${BLUE}📝 Please check your rclone configuration${NC}"
    exit 1
fi

# Create remote directory if it doesn't exist
rclone mkdir "$CLOUD_REMOTE" 2>/dev/null || true

# Upload with progress
if rclone copy "$BACKUP_FILE" "$CLOUD_REMOTE/" --progress; then
    echo -e "${GREEN}✅ Backup uploaded successfully${NC}"
    
    # Verify upload
    if rclone check "$BACKUP_FILE" "$CLOUD_REMOTE/$BACKUP_FILENAME" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Upload verified${NC}"
        
        # List recent backups
        echo ""
        echo -e "${BLUE}📋 Recent backups:${NC}"
        rclone lsf "$CLOUD_REMOTE/" --format "s" --files-only | tail -5 | while read file; do
            echo "  - $file"
        done
        
        exit 0
    else
        echo -e "${YELLOW}⚠️  Upload verification failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Upload failed${NC}"
    exit 1
fi
