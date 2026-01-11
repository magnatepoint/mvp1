#!/bin/bash
# Restore from backup

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
TEMP_DIR=$(mktemp -d)

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Restore from Backup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Load environment
if [ -f "$BACKEND_DIR/.env" ]; then
    export $(grep -v '^#' "$BACKEND_DIR/.env" | xargs)
fi

# Determine backup source
if [ $# -ge 1 ]; then
    BACKUP_FILE="$1"
else
    # List available backups
    echo -e "${BLUE}📋 Available backups:${NC}"
    echo ""
    
    # Local backups
    if [ -d "$BACKUP_DIR" ]; then
        local_backups=($(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
        if [ ${#local_backups[@]} -gt 0 ]; then
            echo -e "${GREEN}Local backups:${NC}"
            for i in "${!local_backups[@]}"; do
                backup_file="${local_backups[$i]}"
                backup_name=$(basename "$backup_file")
                backup_size=$(du -h "$backup_file" | cut -f1)
                backup_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$backup_file" 2>/dev/null || stat -c "%y" "$backup_file" 2>/dev/null | cut -d' ' -f1-2)
                echo "  $((i+1)). $backup_name ($backup_size) - $backup_date"
            done
            echo ""
        fi
    fi
    
    # Cloud backups
    CLOUD_STORAGE=${CLOUD_STORAGE:-"gdrive"}
    if command -v rclone &> /dev/null && rclone listremotes | grep -q "^${CLOUD_STORAGE}:"; then
        CLOUD_REMOTE=${CLOUD_REMOTE:-"${CLOUD_STORAGE}:mvp-backups"}
        echo -e "${GREEN}Cloud backups:${NC}"
        cloud_backups=($(rclone lsf "$CLOUD_REMOTE/" --format "p" --files-only | grep "\.tar\.gz$" | sort -r))
        if [ ${#cloud_backups[@]} -gt 0 ]; then
            for i in "${!cloud_backups[@]}"; do
                backup_name="${cloud_backups[$i]}"
                echo "  $((i+${#local_backups[@]}+1)). $backup_name (cloud)"
            done
        fi
        echo ""
    fi
    
    read -p "Enter backup number or path: " backup_input
    
    # Check if it's a number
    if [[ "$backup_input" =~ ^[0-9]+$ ]]; then
        backup_index=$((backup_input - 1))
        if [ $backup_index -lt ${#local_backups[@]} ]; then
            BACKUP_FILE="${local_backups[$backup_index]}"
        elif [ $backup_index -lt $((${#local_backups[@]} + ${#cloud_backups[@]})) ]; then
            cloud_index=$((backup_index - ${#local_backups[@]}))
            BACKUP_NAME="${cloud_backups[$cloud_index]}"
            BACKUP_FILE="$TEMP_DIR/$BACKUP_NAME"
            echo -e "${BLUE}📥 Downloading from cloud...${NC}"
            rclone copy "$CLOUD_REMOTE/$BACKUP_NAME" "$TEMP_DIR/"
        else
            echo -e "${RED}❌ Invalid backup number${NC}"
            exit 1
        fi
    else
        BACKUP_FILE="$backup_input"
    fi
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}📦 Extracting backup...${NC}"
cd "$TEMP_DIR"
tar -xzf "$BACKUP_FILE" 2>/dev/null || tar -xzf "$BACKUP_FILE" * 2>/dev/null

# Check manifest
if [ -f "manifest.json" ]; then
    echo -e "${GREEN}✅ Backup manifest found${NC}"
    cat manifest.json | python3 -m json.tool 2>/dev/null || cat manifest.json
    echo ""
fi

# Decrypt files if needed
if command -v gpg &> /dev/null; then
    for encrypted_file in *.gpg; do
        if [ -f "$encrypted_file" ]; then
            decrypted_file="${encrypted_file%.gpg}"
            echo -e "${BLUE}🔓 Decrypting $encrypted_file...${NC}"
            if gpg --decrypt --output "$decrypted_file" "$encrypted_file" 2>/dev/null; then
                rm "$encrypted_file"
                echo -e "${GREEN}✅ Decrypted $decrypted_file${NC}"
            else
                echo -e "${YELLOW}⚠️  Decryption failed for $encrypted_file${NC}"
            fi
        fi
    done
fi

# Restore Redis
if [ -f "redis-dump.rdb" ]; then
    echo -e "${BLUE}🔴 Restoring Redis data...${NC}"
    read -p "This will overwrite current Redis data. Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Stop Redis temporarily
        docker stop mvp-redis > /dev/null 2>&1 || true
        docker cp "redis-dump.rdb" mvp-redis:/data/dump.rdb
        docker start mvp-redis > /dev/null 2>&1
        echo -e "${GREEN}✅ Redis data restored${NC}"
    fi
fi

# Restore environment
if [ -f ".env" ]; then
    echo -e "${BLUE}📝 Restoring environment configuration...${NC}"
    read -p "This will overwrite current .env file. Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp ".env" "$BACKEND_DIR/.env"
        chmod 600 "$BACKEND_DIR/.env"
        echo -e "${GREEN}✅ Environment configuration restored${NC}"
    fi
fi

# Restore Cloudflare credentials
if [ -f "cloudflare-credentials.json" ]; then
    echo -e "${BLUE}🌐 Restoring Cloudflare Tunnel credentials...${NC}"
    mkdir -p "$DEPLOY_DIR/cloudflare"
    cp "cloudflare-credentials.json" "$DEPLOY_DIR/cloudflare/credentials.json"
    chmod 600 "$DEPLOY_DIR/cloudflare/credentials.json"
    echo -e "${GREEN}✅ Cloudflare credentials restored${NC}"
fi

# Restore Cloudflare config
if [ -f "cloudflare-config.yml" ]; then
    mkdir -p "$DEPLOY_DIR/cloudflare"
    cp "cloudflare-config.yml" "$DEPLOY_DIR/cloudflare/config.yml"
    chmod 644 "$DEPLOY_DIR/cloudflare/config.yml"
    echo -e "${GREEN}✅ Cloudflare config restored${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   ✅ Restore completed!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "  1. Review restored configuration"
echo "  2. Restart services: docker-compose restart"
echo "  3. Run health check: $SCRIPT_DIR/health-check.sh"
