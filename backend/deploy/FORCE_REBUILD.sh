#!/bin/bash
# Force complete rebuild of backend

set -e

echo "🔄 Force rebuilding backend with latest code..."

cd /opt/mvp-backend/backend || {
    echo "❌ Error: /opt/mvp-backend/backend not found"
    exit 1
}

echo "📥 Pulling latest code..."
git pull origin main

echo "🛑 Stopping all containers..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down

echo "🗑️  Removing old backend image..."
docker rmi backend-backend 2>/dev/null || echo "   (No old image to remove)"

echo "🔨 Building backend from scratch (no cache)..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache backend

echo "🚀 Starting all services..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

echo "⏳ Waiting for services to start..."
sleep 10

echo "📋 Checking backend status..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps backend

echo ""
echo "📋 Backend logs (last 30 lines):"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs --tail=30 backend

echo ""
echo "✅ Rebuild complete!"
echo ""
echo "🧪 Test the endpoint:"
echo "   curl https://api.monytix.ai/v1/spendsense/kpis"
