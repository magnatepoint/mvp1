#!/bin/bash
# Helper script to run migrations
# Usage: ./run_migration.sh <migration_file>

if [ -z "$1" ]; then
    echo "Usage: $0 <migration_file>"
    echo "Example: $0 migrations/047_normalize_existing_merchant_names.sql"
    exit 1
fi

MIGRATION_FILE="$1"

# Try to get database name from POSTGRES_URL if set
if [ -n "$POSTGRES_URL" ]; then
    # Extract database name from postgres://user:pass@host:port/dbname format
    DB_NAME=$(echo "$POSTGRES_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
    if [ -n "$DB_NAME" ]; then
        echo "Using database from POSTGRES_URL: $DB_NAME"
        psql "$POSTGRES_URL" -f "backend/$MIGRATION_FILE"
        exit $?
    fi
fi

# Fallback: prompt for database name
if [ -z "$DB_NAME" ]; then
    echo "Please enter your database name (or set POSTGRES_URL environment variable):"
    read -r DB_NAME
fi

# Quote the database name to handle spaces and special characters
psql -d "$DB_NAME" -f "backend/$MIGRATION_FILE"

