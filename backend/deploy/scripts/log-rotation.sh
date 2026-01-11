#!/bin/bash
# Log rotation script

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
LOGS_DIR="$BACKEND_DIR/logs"
RETENTION_DAYS=${RETENTION_DAYS:-7}

echo -e "${BLUE}🔄 Rotating logs...${NC}"

# Rotate Docker logs
if [ -d "$LOGS_DIR" ]; then
    find "$LOGS_DIR" -name "*.log" -type f -mtime +$RETENTION_DAYS -delete
    echo -e "${GREEN}✅ Cleaned up logs older than $RETENTION_DAYS days${NC}"
fi

# Rotate Docker container logs (if using json-file driver)
docker system prune -f --filter "until=168h" > /dev/null 2>&1 || true

echo -e "${GREEN}✅ Log rotation complete${NC}"
