# Fix Docker Compose Command

## Issue
`docker-compose` command not found. You need to use `docker compose` (with space) instead.

## Solution

### Option 1: Use Docker Compose V2 (Recommended)
Docker Compose V2 is installed as a plugin. Use `docker compose` (with space) instead of `docker-compose`:

```bash
cd /opt/mvp-backend/backend

# Build
docker compose -f docker-compose.yml -f docker-compose.prod.yml build

# Start
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Check status
docker compose -f docker-compose.yml -f docker-compose.prod.yml ps

# View logs
docker compose -f docker-compose.yml -f docker-compose.prod.yml logs -f
```

### Option 2: Install Standalone docker-compose
If you prefer the old `docker-compose` command:

```bash
# Install standalone docker-compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

### Option 3: Create Alias
Create an alias so `docker-compose` works:

```bash
echo 'alias docker-compose="docker compose"' >> ~/.bashrc
source ~/.bashrc
```

## Quick Start Commands (using docker compose)

```bash
cd /opt/mvp-backend/backend

# Make sure .env exists
if [ ! -f .env ]; then
    ./deploy/create-env-file.sh
    nano .env
fi

# Build and start
docker compose -f docker-compose.yml -f docker-compose.prod.yml build
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Check status
docker compose -f docker-compose.yml -f docker-compose.prod.yml ps

# View logs
docker compose -f docker-compose.yml -f docker-compose.prod.yml logs -f backend
```
