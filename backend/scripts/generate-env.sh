#!/bin/bash
# Interactive script to generate .env file from template

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_FILE="$BACKEND_DIR/.env.production.example"
ENV_FILE="$BACKEND_DIR/.env"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Environment Configuration Generator${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${YELLOW}⚠️  Template file not found: $TEMPLATE_FILE${NC}"
    exit 1
fi

if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}⚠️  .env file already exists at $ENV_FILE${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    cp "$ENV_FILE" "$ENV_FILE.backup"
    echo -e "${GREEN}✅ Backed up existing .env to .env.backup${NC}"
fi

# Copy template
cp "$TEMPLATE_FILE" "$ENV_FILE"

echo -e "${BLUE}📝 Please fill in the following values:${NC}"
echo ""

# Function to prompt for value
prompt_value() {
    local key=$1
    local description=$2
    local current_value=$(grep "^${key}=" "$ENV_FILE" | cut -d '=' -f2- || echo "")
    
    if [ -n "$current_value" ] && [ "$current_value" != "your-*" ]; then
        echo -e "${GREEN}Current value for ${key}: ${current_value}${NC}"
        read -p "Press Enter to keep, or type new value: " new_value
        if [ -n "$new_value" ]; then
            sed -i.bak "s|^${key}=.*|${key}=${new_value}|" "$ENV_FILE"
            rm -f "$ENV_FILE.bak"
        fi
    else
        read -p "${description} (${key}): " value
        if [ -n "$value" ]; then
            sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
            rm -f "$ENV_FILE.bak"
        fi
    fi
}

# Required variables
prompt_value "ENVIRONMENT" "Environment (production/development)"
prompt_value "SUPABASE_URL" "Supabase URL"
prompt_value "SUPABASE_ANON_KEY" "Supabase Anon Key"
prompt_value "SUPABASE_SERVICE_ROLE_KEY" "Supabase Service Role Key"
prompt_value "SUPABASE_JWT_SECRET" "Supabase JWT Secret"
prompt_value "FRONTEND_ORIGIN" "Frontend Origin (for CORS)"
prompt_value "POSTGRES_URL" "PostgreSQL Connection String"
prompt_value "REDIS_URL" "Redis URL"
prompt_value "GMAIL_CLIENT_ID" "Gmail Client ID"
prompt_value "GMAIL_CLIENT_SECRET" "Gmail Client Secret"
prompt_value "GMAIL_REDIRECT_URI" "Gmail Redirect URI"

# Optional variables
read -p "Do you want to configure GCP Pub/Sub? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    prompt_value "GCP_PROJECT_ID" "GCP Project ID"
    prompt_value "GOOGLE_APPLICATION_CREDENTIALS" "Path to Gmail Pub/Sub key JSON"
fi

# Validate required variables
echo ""
echo -e "${BLUE}🔍 Validating configuration...${NC}"

missing_vars=()
while IFS= read -r line; do
    if [[ $line =~ ^[A-Z_]+=.*your-.* ]] || [[ $line =~ ^[A-Z_]+=$ ]]; then
        var_name=$(echo "$line" | cut -d '=' -f1)
        if [[ ! "$var_name" =~ ^(GCP_PROJECT_ID|GOOGLE_APPLICATION_CREDENTIALS)$ ]]; then
            missing_vars+=("$var_name")
        fi
    fi
done < "$ENV_FILE"

if [ ${#missing_vars[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: The following variables may not be set:${NC}"
    printf '%s\n' "${missing_vars[@]}"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Please edit $ENV_FILE manually."
        exit 1
    fi
fi

echo -e "${GREEN}✅ Environment file created at $ENV_FILE${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "  1. Review the generated .env file"
echo "  2. Make sure all required values are set"
echo "  3. Never commit .env to version control"
