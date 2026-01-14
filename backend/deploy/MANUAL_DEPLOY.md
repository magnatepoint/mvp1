# Manual Deployment Guide

Since CI/CD has network connectivity issues, use this manual deployment process.

## Prerequisites

Before your first deployment, you need to set up the server.

### 1. Server Setup (One-time)

Run the included setup script on your Ubuntu server. This script will install Docker, Git, and create the necessary directories.

**SSH into your server:**
```bash
ssh username@your-server-ip
```

**Copy and run the script (or copy-paste its content):**
You can copy the `deploy/setup_ubuntu.sh` file to your server:
```bash
# From your local machine
scp deploy/setup_ubuntu.sh username@your-server-ip:~/
```

**On the server:**
```bash
chmod +x setup_ubuntu.sh
sudo ./setup_ubuntu.sh
```

### 2. Configure Environment
The `manual-deploy.sh` script will automatically copy your local `.env` and `gmail-pubsub-key.json` to the server if run from your local machine.

However, you can still manually create them if needed:
```bash
nano /opt/mvp-backend/backend/.env
# Paste your environment variables
```

---

## Deploying

### Option 1: Deploy from Your Local Machine (Recommended)

**From your Mac (in the mvp/backend directory):**

```bash
cd /Users/santosh/coding/mvp/backend

# Set server details (if not set in your shell profile)
export SERVER_USER=your-username
export SERVER_HOST=your-server-ip

# Run deployment
./deploy/manual-deploy.sh
```

The script will:
- SSH into your server
- **Upload secrets** (`.env`, `gmail-pubsub-key.json`)
- Pull latest code
- Rebuild Docker images
- Run migrations
- Restart services
- Run health checks

### Option 2: Deploy Directly on Server

**SSH into your server first:**

```bash
ssh username@your-server-ip
cd /opt/mvp-backend/backend

# Run the deploy script
./deploy/manual-deploy.sh
```

## Step-by-Step Manual Process

If you prefer to do it step by step:

```bash
# 1. SSH into server
ssh malla@192.168.68.113

# 2. Navigate to backend directory
cd /opt/mvp-backend/backend

# 3. Pull latest code
git pull origin main

# 4. Rebuild images
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache

# 5. Run migrations (optional)
# ./deploy/scripts/run-migrations.sh

# 6. Restart services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 7. Check status
docker-compose ps

# 8. Check health
# ./deploy/scripts/health-check.sh
```

## Troubleshooting

### "git pull" fails
Ensure your server has SSH keys added to GitHub or your repo is public.
```bash
# Generate SSH key on server
ssh-keygen -t ed25519 -C "server@deploy"
cat ~/.ssh/id_ed25519.pub
# Add this key to your GitHub Repo -> Settings -> Deploy Keys
```

### Docker build fails
```bash
docker system prune -a
```

### Services won't start
```bash
docker-compose logs
cat .env # Check variables
```

