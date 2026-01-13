#!/bin/bash
# Check Docker status and start containers

set -e

BACKEND_DIR="/opt/mvp-backend/backend"

echo "🔍 Checking Docker and container status..."
echo ""

# Check if Docker is running
if ! docker ps &> /dev/null; then
    echo "❌ Docker is not running or you don't have permissions"
    echo ""
    echo "Try:"
    echo "  sudo systemctl start docker"
    echo "  sudo usermod -aG docker \$USER"
    echo "  # Then log out and back in"
    exit 1
fi

echo "✅ Docker is running"
echo ""

# Check if we're in the right directory
if [ ! -f "$BACKEND_DIR/docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found in $BACKEND_DIR"
    echo ""
    echo "Please ensure:"
    echo "  1. Repository is cloned: git clone https://github.com/magnatepoint/mvp1.git /opt/mvp-backend"
    echo "  2. You're in the backend directory: cd /opt/mvp-backend/backend"
    exit 1
fi

cd "$BACKEND_DIR"

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "⚠️  .env file not found!"
    echo "Creating template .env file..."
    ./deploy/create-env-file.sh
    echo ""
    echo "⚠️  Please edit .env with your actual values before starting containers"
    read -p "Press Enter after editing .env file, or Ctrl+C to cancel..."
fi

echo ""
echo "📋 Current container status:"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps

echo ""
echo "🔨 Building images (if needed)..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

echo ""
echo "🚀 Starting containers..."
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

echo ""
echo "⏳ Waiting for containers to start..."
sleep 10

echo ""
echo "📊 Container status:"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps

echo ""
echo "📋 Backend logs (last 30 lines):"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs --tail=30 backend

echo ""
echo "✅ Done!"
echo ""
echo "To view all logs: docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs -f"
echo "To check status: docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps"
