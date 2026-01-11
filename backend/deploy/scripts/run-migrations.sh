#!/bin/bash
# Run database migrations

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
MIGRATIONS_DIR="$BACKEND_DIR/migrations"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Database Migrations${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Load environment
if [ -f "$BACKEND_DIR/.env" ]; then
    export $(grep -v '^#' "$BACKEND_DIR/.env" | xargs)
else
    echo -e "${RED}❌ .env file not found${NC}"
    exit 1
fi

# Check if POSTGRES_URL is set
if [ -z "$POSTGRES_URL" ]; then
    echo -e "${RED}❌ POSTGRES_URL not set in .env${NC}"
    exit 1
fi

# Check if migrations directory exists
if [ ! -d "$MIGRATIONS_DIR" ]; then
    echo -e "${YELLOW}⚠️  Migrations directory not found: $MIGRATIONS_DIR${NC}"
    exit 1
fi

# Get list of migration files
migrations=($(ls -1 "$MIGRATIONS_DIR"/*.sql 2>/dev/null | sort))

if [ ${#migrations[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No migration files found${NC}"
    exit 0
fi

echo -e "${BLUE}📋 Found ${#migrations[@]} migration files${NC}"
echo ""

# Run migrations using psql or asyncpg
if command -v psql &> /dev/null; then
    # Extract connection details from POSTGRES_URL
    # Format: postgresql://user:password@host:port/database
    db_url="$POSTGRES_URL"
    
    for migration in "${migrations[@]}"; do
        migration_name=$(basename "$migration")
        echo -e "${BLUE}🔄 Running $migration_name...${NC}"
        
        if psql "$db_url" -f "$migration" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $migration_name completed${NC}"
        else
            # Check if error is due to already applied migration
            if psql "$db_url" -f "$migration" 2>&1 | grep -q "already exists\|duplicate"; then
                echo -e "${YELLOW}⚠️  $migration_name already applied (skipping)${NC}"
            else
                echo -e "${RED}❌ $migration_name failed${NC}"
                exit 1
            fi
        fi
    done
else
    echo -e "${YELLOW}⚠️  psql not found. Please run migrations manually or install PostgreSQL client${NC}"
    echo -e "${BLUE}📝 Migration files:${NC}"
    for migration in "${migrations[@]}"; do
        echo "  - $(basename "$migration")"
    done
    exit 1
fi

echo ""
echo -e "${GREEN}✅ All migrations completed!${NC}"
