#!/bin/bash
# Update Cloudflare tunnel to use port 8001

set -e

CONFIG_FILE="/opt/mvp-backend/backend/deploy/cloudflare/config.yml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Cloudflare config not found at $CONFIG_FILE"
    exit 1
fi

echo "📝 Updating Cloudflare config to use port 8001..."

# Update the port in the config file
sed -i 's|service: http://localhost:8000|service: http://localhost:8001|g' "$CONFIG_FILE"

echo "✅ Updated Cloudflare config"
echo ""
echo "📋 Updated config:"
grep "service:" "$CONFIG_FILE"

echo ""
echo "🔄 Restarting Cloudflare tunnel..."

# Try systemd service first
if systemctl is-active --quiet cloudflare-tunnel 2>/dev/null; then
    echo "   Using systemd service..."
    sudo systemctl restart cloudflare-tunnel
    echo "✅ Cloudflare tunnel restarted via systemd"
elif docker ps --format '{{.Names}}' | grep -q cloudflare; then
    echo "   Using docker-compose..."
    cd /opt/mvp-backend/backend
    docker-compose -f deploy/cloudflare/docker-compose.tunnel.yml restart
    echo "✅ Cloudflare tunnel restarted via docker-compose"
else
    echo "⚠️  Cloudflare tunnel not found. Please restart manually."
fi

echo ""
echo "✅ Done! Cloudflare tunnel should now route to port 8001"
