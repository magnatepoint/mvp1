#!/bin/bash
# Main backup script - backs up Redis, config, and credentials

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
BACKUP_DIR="$BACKEND_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mvp-backup-${TIMESTAMP}"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
TEMP_DIR=$(mktemp -d)

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Backup Process${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR" "$TEMP_DIR"

# Load environment
if [ -f "$BACKEND_DIR/.env" ]; then
    export $(grep -v '^#' "$BACKEND_DIR/.env" | xargs)
fi

# 1. Backup Redis data
echo -e "${BLUE}🔴 Backing up Redis data...${NC}"
if docker exec mvp-redis redis-cli BGSAVE > /dev/null 2>&1; then
    # Wait for save to complete
    sleep 2
    docker exec mvp-redis redis-cli SAVE > /dev/null 2>&1 || true
    
    # Copy RDB file
    if docker cp mvp-redis:/data/dump.rdb "$TEMP_DIR/redis-dump.rdb" 2>/dev/null; then
        echo -e "${GREEN}✅ Redis backup created${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not copy Redis dump file${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Redis backup skipped (container not running)${NC}"
fi

# 2. Backup environment configuration (will be encrypted)
echo -e "${BLUE}📝 Backing up environment configuration...${NC}"
if [ -f "$BACKEND_DIR/.env" ]; then
    cp "$BACKEND_DIR/.env" "$TEMP_DIR/.env"
    echo -e "${GREEN}✅ Environment configuration backed up${NC}"
else
    echo -e "${YELLOW}⚠️  .env file not found${NC}"
fi

# 3. Backup Cloudflare Tunnel credentials
echo -e "${BLUE}🌐 Backing up Cloudflare Tunnel credentials...${NC}"
if [ -f "$DEPLOY_DIR/cloudflare/credentials.json" ]; then
    cp "$DEPLOY_DIR/cloudflare/credentials.json" "$TEMP_DIR/cloudflare-credentials.json"
    echo -e "${GREEN}✅ Cloudflare credentials backed up${NC}"
else
    echo -e "${YELLOW}⚠️  Cloudflare credentials not found${NC}"
fi

# 4. Backup Cloudflare config
if [ -f "$DEPLOY_DIR/cloudflare/config.yml" ]; then
    cp "$DEPLOY_DIR/cloudflare/config.yml" "$TEMP_DIR/cloudflare-config.yml"
fi

# 5. Backup application logs (optional, recent only)
if [ -d "$BACKEND_DIR/logs" ]; then
    echo -e "${BLUE}📋 Backing up recent logs...${NC}"
    mkdir -p "$TEMP_DIR/logs"
    find "$BACKEND_DIR/logs" -name "*.log" -mtime -7 -exec cp {} "$TEMP_DIR/logs/" \; 2>/dev/null || true
    echo -e "${GREEN}✅ Logs backed up${NC}"
fi

# 6. Create backup manifest
cat > "$TEMP_DIR/manifest.json" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "backup_name": "$BACKUP_NAME",
  "version": "1.0",
  "components": {
    "redis": $(test -f "$TEMP_DIR/redis-dump.rdb" && echo "true" || echo "false"),
    "environment": $(test -f "$TEMP_DIR/.env" && echo "true" || echo "false"),
    "cloudflare_credentials": $(test -f "$TEMP_DIR/cloudflare-credentials.json" && echo "true" || echo "false"),
    "cloudflare_config": $(test -f "$TEMP_DIR/cloudflare-config.yml" && echo "true" || echo "false"),
    "logs": $(test -d "$TEMP_DIR/logs" && echo "true" || echo "false")
  }
}
EOF

# 7. Encrypt sensitive files with GPG (if GPG key is available)
if command -v gpg &> /dev/null; then
    GPG_RECIPIENT=${GPG_RECIPIENT:-""}
    if [ -n "$GPG_RECIPIENT" ]; then
        echo -e "${BLUE}🔐 Encrypting sensitive files...${NC}"
        if [ -f "$TEMP_DIR/.env" ]; then
            gpg --encrypt --recipient "$GPG_RECIPIENT" --output "$TEMP_DIR/.env.gpg" "$TEMP_DIR/.env" 2>/dev/null && rm "$TEMP_DIR/.env" && echo -e "${GREEN}✅ .env encrypted${NC}" || echo -e "${YELLOW}⚠️  GPG encryption failed, keeping unencrypted${NC}"
        fi
        if [ -f "$TEMP_DIR/cloudflare-credentials.json" ]; then
            gpg --encrypt --recipient "$GPG_RECIPIENT" --output "$TEMP_DIR/cloudflare-credentials.json.gpg" "$TEMP_DIR/cloudflare-credentials.json" 2>/dev/null && rm "$TEMP_DIR/cloudflare-credentials.json" && echo -e "${GREEN}✅ Cloudflare credentials encrypted${NC}" || echo -e "${YELLOW}⚠️  GPG encryption failed, keeping unencrypted${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  GPG_RECIPIENT not set, skipping encryption${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  GPG not available, skipping encryption${NC}"
fi

# 8. Create compressed archive
echo -e "${BLUE}📦 Creating backup archive...${NC}"
cd "$TEMP_DIR"
tar -czf "$BACKUP_PATH.tar.gz" . 2>/dev/null || tar -czf "$BACKUP_PATH.tar.gz" * 2>/dev/null
cd - > /dev/null

if [ -f "$BACKUP_PATH.tar.gz" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_PATH.tar.gz" | cut -f1)
    echo -e "${GREEN}✅ Backup archive created: $BACKUP_PATH.tar.gz (${BACKUP_SIZE})${NC}"
else
    echo -e "${RED}❌ Failed to create backup archive${NC}"
    exit 1
fi

# 9. Upload to cloud storage
echo ""
echo -e "${BLUE}☁️  Uploading to cloud storage...${NC}"
if [ -f "$SCRIPT_DIR/backup-cloud-upload.sh" ]; then
    if bash "$SCRIPT_DIR/backup-cloud-upload.sh" "$BACKUP_PATH.tar.gz"; then
        echo -e "${GREEN}✅ Backup uploaded successfully${NC}"
        
        # Clean up local backup after successful upload
        if [ "${CLEANUP_LOCAL_BACKUP:-true}" = "true" ]; then
            echo -e "${BLUE}🧹 Cleaning up local backup...${NC}"
            rm -f "$BACKUP_PATH.tar.gz"
            echo -e "${GREEN}✅ Local backup cleaned up${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Cloud upload failed, keeping local backup${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Cloud upload script not found, skipping upload${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✅ Backup completed successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📋 Backup details:${NC}"
echo "  - Name: $BACKUP_NAME"
echo "  - Location: $BACKUP_PATH.tar.gz"
if [ -f "$BACKUP_PATH.tar.gz" ]; then
    echo "  - Size: $(du -h "$BACKUP_PATH.tar.gz" | cut -f1)"
fi
