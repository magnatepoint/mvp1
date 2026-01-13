#!/bin/bash
# Quick update script for server

set -e

echo "🔄 Updating backend server..."

cd /opt/mvp-backend/backend || {
    echo "❌ Error: /opt/mvp-backend/backend not found"
    exit 1
}

echo "📥 Pulling latest code..."
git pull origin main

echo "🛑 Stopping services..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down

echo "🔨 Building backend..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache backend

echo "🚀 Starting services..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

echo "⏳ Waiting for services to start..."
sleep 5

echo "✅ Checking backend status..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps backend

echo ""
echo "📋 Backend logs (last 20 lines):"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs --tail=20 backend

echo ""
echo "🧪 Testing endpoint..."
curl -s https://api.monytix.ai/v1/spendsense/kpis | head -c 100
echo ""

echo "✅ Update complete!"
