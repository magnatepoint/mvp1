#!/bin/bash
# Interactive script to set up Cloudflare Tunnel

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"
CLOUDFLARE_DIR="$DEPLOY_DIR/cloudflare"
CONFIG_FILE="$CLOUDFLARE_DIR/config.yml"
CREDENTIALS_FILE="$CLOUDFLARE_DIR/credentials.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Cloudflare Tunnel Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo -e "${YELLOW}⚠️  cloudflared not found. Installing...${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux installation
        curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
        chmod +x /usr/local/bin/cloudflared
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS installation
        if command -v brew &> /dev/null; then
            brew install cloudflared
        else
            echo -e "${RED}❌ Please install cloudflared manually: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Unsupported OS. Please install cloudflared manually.${NC}"
        exit 1
    fi
fi

# Create cloudflare directory
mkdir -p "$CLOUDFLARE_DIR"

# Check if tunnel already exists
if [ -f "$CREDENTIALS_FILE" ]; then
    echo -e "${YELLOW}⚠️  Tunnel credentials already exist at $CREDENTIALS_FILE${NC}"
    read -p "Do you want to create a new tunnel? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✅ Using existing tunnel credentials${NC}"
        exit 0
    fi
fi

# Login to Cloudflare
echo -e "${BLUE}🔐 Logging in to Cloudflare...${NC}"
cloudflared tunnel login

# Get tunnel name
read -p "Enter tunnel name (default: mvp-backend-tunnel): " tunnel_name
tunnel_name=${tunnel_name:-mvp-backend-tunnel}

# Create tunnel
echo -e "${BLUE}🚇 Creating tunnel: $tunnel_name${NC}"
cloudflared tunnel create "$tunnel_name"

# Get domain
read -p "Enter your domain (e.g., api.yourdomain.com): " domain
if [ -z "$domain" ]; then
    echo -e "${RED}❌ Domain is required${NC}"
    exit 1
fi

# Extract hostname and domain
hostname=$(echo "$domain" | cut -d'.' -f1)
domain_name=$(echo "$domain" | cut -d'.' -f2-)

# Create DNS route
echo -e "${BLUE}🌐 Creating DNS route...${NC}"
cloudflared tunnel route dns "$tunnel_name" "$domain"

# Generate credentials file location
echo -e "${BLUE}📝 Getting tunnel credentials...${NC}"
tunnel_id=$(cloudflared tunnel list | grep "$tunnel_name" | awk '{print $1}' || echo "")

if [ -z "$tunnel_id" ]; then
    echo -e "${RED}❌ Failed to get tunnel ID${NC}"
    exit 1
fi

# Get account ID
account_id=$(cloudflared tunnel info "$tunnel_name" | grep "Account ID" | awk '{print $3}' || echo "")

if [ -z "$account_id" ]; then
    echo -e "${YELLOW}⚠️  Could not get account ID automatically${NC}"
    read -p "Enter your Cloudflare Account ID: " account_id
fi

# Create credentials file
cat > "$CREDENTIALS_FILE" <<EOF
{
  "AccountTag": "$account_id",
  "TunnelSecret": "$(cloudflared tunnel token "$tunnel_name" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r '.TunnelSecret' || echo 'MANUAL_SETUP_REQUIRED')",
  "TunnelID": "$tunnel_id",
  "TunnelName": "$tunnel_name"
}
EOF

# Alternative method to get credentials
if grep -q "MANUAL_SETUP_REQUIRED" "$CREDENTIALS_FILE"; then
    echo -e "${YELLOW}⚠️  Could not automatically extract credentials${NC}"
    echo -e "${BLUE}Please run the following command and copy the credentials:${NC}"
    echo "cloudflared tunnel token $tunnel_name"
    echo ""
    read -p "Paste the token here: " token
    
    # Extract from token
    if [ -n "$token" ]; then
        # Token is base64 encoded JSON
        decoded=$(echo "$token" | cut -d'.' -f2 | base64 -d 2>/dev/null || echo "")
        if [ -n "$decoded" ]; then
            echo "$decoded" > "$CREDENTIALS_FILE"
        else
            echo -e "${YELLOW}⚠️  Could not decode token. Please edit $CREDENTIALS_FILE manually${NC}"
        fi
    fi
fi

# Update config file
if [ -f "$CONFIG_FILE" ]; then
    sed -i.bak "s/tunnel:.*/tunnel: $tunnel_name/" "$CONFIG_FILE"
    sed -i.bak "s/hostname:.*/hostname: $domain/" "$CONFIG_FILE"
    sed -i.bak "s/httpHostHeader:.*/httpHostHeader: $domain/" "$CONFIG_FILE"
    rm -f "$CONFIG_FILE.bak"
else
    cat > "$CONFIG_FILE" <<EOF
tunnel: $tunnel_name
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: $domain
    service: http://localhost:8001
    originRequest:
      noHappyEyeballs: true
      keepAliveConnections: 100
      keepAliveTimeout: 90s
      httpHostHeader: $domain
      http2Origin: true
      compressionQuality: 0

  - service: http_status:404
EOF
fi

# Set proper permissions
chmod 600 "$CREDENTIALS_FILE"
chmod 644 "$CONFIG_FILE"

echo ""
echo -e "${GREEN}✅ Cloudflare Tunnel setup complete!${NC}"
echo ""
echo -e "${BLUE}📋 Configuration:${NC}"
echo "  - Tunnel name: $tunnel_name"
echo "  - Domain: $domain"
echo "  - Config file: $CONFIG_FILE"
echo "  - Credentials: $CREDENTIALS_FILE"
echo ""
echo -e "${BLUE}📝 Next steps:${NC}"
echo "  1. Verify DNS is pointing to Cloudflare"
echo "  2. Test the tunnel: cloudflared tunnel run $tunnel_name"
echo "  3. Add the tunnel service to docker-compose.yml"
