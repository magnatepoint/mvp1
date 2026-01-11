# MVP Backend Production Deployment Guide

Complete guide for deploying the MVP backend to production on Ubuntu using Docker Compose, Cloudflare Tunnel, and automated cloud backups.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Initial Deployment](#initial-deployment)
- [Disaster Recovery](#disaster-recovery)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Environment Variables](#environment-variables)

## Prerequisites

- Ubuntu 20.04 or later
- Root or sudo access
- Domain name managed by Cloudflare
- PostgreSQL database (can be on separate server)
- Google Drive or OneDrive account (for backups)

## Quick Start

### Initial Deployment

1. **Copy code to server:**
   
   **Option A: Using Git (Recommended)**
   ```bash
   git clone <your-repo-url> /opt/mvp-backend
   cd /opt/mvp-backend
   ```
   
   **Option B: Using SCP/rsync (from your local machine)**
   ```bash
   # From your local machine
   rsync -avz --exclude 'venv' --exclude '.venv' --exclude '__pycache__' \
     --exclude '*.pyc' --exclude '.git' --exclude '.env' \
     backend/ user@your-server-ip:/opt/mvp-backend/
   ```
   
   See `DEPLOYMENT.md` for detailed copying instructions.

2. **Run server setup:**
   ```bash
   sudo ./deploy/scripts/setup-server.sh
   ```

3. **Configure environment:**
   ```bash
   ./scripts/generate-env.sh
   # Or manually copy and edit .env.production.example to .env
   ```

4. **Set up Cloudflare Tunnel:**
   ```bash
   ./deploy/scripts/setup-cloudflare-tunnel.sh
   ```

5. **Set up cloud backup:**
   ```bash
   ./deploy/scripts/setup-cloud-backup.sh
   ```

6. **Deploy:**
   ```bash
   ./deploy/deploy.sh
   ```

7. **Install systemd services (optional):**
   ```bash
   sudo ./deploy/scripts/install-service.sh
   ```

### Disaster Recovery / New Server

For deploying to a new server from backup:

```bash
sudo ./deploy/scripts/deploy-new-server.sh
```

This script will:
- Set up the server
- Restore from latest backup
- Configure Cloudflare Tunnel
- Deploy the application
- Install systemd services

## Initial Deployment

### Step-by-Step Guide

#### 1. Server Setup

Run the server setup script to install all required dependencies:

```bash
sudo ./deploy/scripts/setup-server.sh
```

This installs:
- Docker and Docker Compose
- rclone (for cloud backups)
- cloudflared (for Cloudflare Tunnel)
- PostgreSQL client
- Redis tools
- Configures firewall (UFW)

**Note:** You may need to log out and back in for Docker group changes to take effect.

#### 2. Environment Configuration

Generate your `.env` file:

```bash
./scripts/generate-env.sh
```

Or manually copy the template:

```bash
cp .env.production.example .env
nano .env
```

See [Environment Variables](#environment-variables) for required values.

#### 3. Cloudflare Tunnel Setup

Set up Cloudflare Tunnel for secure routing:

```bash
./deploy/scripts/setup-cloudflare-tunnel.sh
```

This will:
- Install cloudflared if needed
- Authenticate with Cloudflare
- Create a tunnel
- Configure DNS routes
- Generate credentials

**Requirements:**
- Domain must be managed by Cloudflare
- You need Cloudflare account access

#### 4. Cloud Backup Setup

Configure automated backups to Google Drive or OneDrive:

```bash
./deploy/scripts/setup-cloud-backup.sh
```

This will:
- Install rclone if needed
- Configure cloud storage (Google Drive or OneDrive)
- Set up authentication
- Optionally configure GPG encryption

#### 5. Deploy Application

Deploy all services:

```bash
./deploy/deploy.sh
```

This will:
- Build Docker images
- Run database migrations
- Start all services (FastAPI, Celery, Redis)
- Run health checks

#### 6. Install Systemd Services (Optional)

For automatic startup on boot:

```bash
sudo ./deploy/scripts/install-service.sh
```

This installs:
- `backend.service` - Main application services
- `cloudflare-tunnel.service` - Cloudflare Tunnel
- `backup.timer` - Daily automated backups

## Disaster Recovery

### Restore from Backup

To restore on a new server:

1. **Run new server deployment:**
   ```bash
   sudo ./deploy/scripts/deploy-new-server.sh
   ```

2. **Or manually restore:**
   ```bash
   ./deploy/scripts/restore.sh
   ```

The restore script will:
- List available backups (local and cloud)
- Download selected backup
- Decrypt encrypted files
- Restore Redis data
- Restore environment configuration
- Restore Cloudflare Tunnel credentials

### Manual Backup

Create a backup manually:

```bash
./deploy/scripts/backup.sh
```

This creates a backup of:
- Redis data
- Environment configuration (`.env`)
- Cloudflare Tunnel credentials
- Recent application logs

Backups are automatically uploaded to cloud storage if configured.

## Configuration

### Docker Compose

The deployment uses two Docker Compose files:

- `docker-compose.yml` - Base configuration
- `docker-compose.prod.yml` - Production overrides

Production settings include:
- Resource limits
- No auto-reload
- Optimized logging
- Multiple workers

### Cloudflare Tunnel

Configuration file: `deploy/cloudflare/config.yml`

Key settings:
- Tunnel name
- Domain routing
- WebSocket support
- HTTP/2 and compression

### Backup Schedule

Backups run daily at 2 AM (configurable via systemd timer).

To change schedule, edit: `deploy/systemd/backup.timer`

## Troubleshooting

### Services Not Starting

1. **Check Docker:**
   ```bash
   docker ps
   docker-compose logs
   ```

2. **Check health:**
   ```bash
   ./deploy/scripts/health-check.sh
   ```

3. **Check environment:**
   ```bash
   cat .env
   ```

### Cloudflare Tunnel Issues

1. **Check tunnel status:**
   ```bash
   cloudflared tunnel list
   cloudflared tunnel info <tunnel-name>
   ```

2. **Test tunnel:**
   ```bash
   cloudflared tunnel run <tunnel-name>
   ```

3. **Check credentials:**
   ```bash
   cat deploy/cloudflare/credentials.json
   ```

### Backup Issues

1. **Test rclone:**
   ```bash
   rclone lsd <remote-name>:
   ```

2. **Test backup:**
   ```bash
   ./deploy/scripts/backup.sh
   ```

3. **Check logs:**
   ```bash
   journalctl -u backup.service
   ```

### Database Connection Issues

1. **Test connection:**
   ```bash
   psql $POSTGRES_URL -c "SELECT 1;"
   ```

2. **Check migrations:**
   ```bash
   ./deploy/scripts/run-migrations.sh
   ```

### Redis Issues

1. **Check Redis:**
   ```bash
   docker exec mvp-redis redis-cli ping
   ```

2. **View Redis logs:**
   ```bash
   docker logs mvp-redis
   ```

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `ENVIRONMENT` | Environment name | `production` |
| `SUPABASE_URL` | Supabase project URL | `https://xxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key | |
| `SUPABASE_JWT_SECRET` | Supabase JWT secret | |
| `FRONTEND_ORIGIN` | Frontend URL for CORS | `https://yourdomain.com` |
| `POSTGRES_URL` | PostgreSQL connection string | `postgresql://user:pass@host:5432/db` |
| `REDIS_URL` | Redis connection string | `redis://redis:6379/0` |
| `GMAIL_CLIENT_ID` | Gmail OAuth client ID | |
| `GMAIL_CLIENT_SECRET` | Gmail OAuth client secret | |
| `GMAIL_REDIRECT_URI` | Gmail OAuth redirect URI | `https://api.yourdomain.com/auth/gmail/callback` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `LOG_LEVEL` | Logging level | `INFO` |
| `WORKERS` | Number of Uvicorn workers | `2` |
| `GCP_PROJECT_ID` | Google Cloud Project ID | |
| `GMAIL_PUBSUB_TOPIC` | Gmail Pub/Sub topic | `gmail-events` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to GCP credentials JSON | |
| `CLOUD_STORAGE` | Cloud storage provider (`gdrive` or `onedrive`) | `gdrive` |
| `CLOUD_REMOTE` | rclone remote path | `gdrive:mvp-backups` |
| `GPG_RECIPIENT` | GPG key ID for encryption | |

## Useful Commands

### Service Management

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart services
docker-compose restart

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f backend
```

### Systemd Services

```bash
# Start backend
sudo systemctl start backend

# Stop backend
sudo systemctl stop backend

# Status
sudo systemctl status backend

# Enable on boot
sudo systemctl enable backend
```

### Backup Management

```bash
# Create backup
./deploy/scripts/backup.sh

# Restore from backup
./deploy/scripts/restore.sh

# List cloud backups
rclone lsf <remote-name>:mvp-backups/
```

### Health Checks

```bash
# Full health check
./deploy/scripts/health-check.sh

# Check API
curl http://localhost:8000/health

# Check Redis
docker exec mvp-redis redis-cli ping
```

## Security Notes

1. **Never commit `.env` file** - It contains sensitive credentials
2. **Use GPG encryption** for backups containing secrets
3. **Restrict CORS** in production to your frontend domain
4. **Keep dependencies updated** regularly
5. **Monitor logs** for suspicious activity
6. **Use strong passwords** for database and services
7. **Enable Cloudflare WAF** for additional protection

## Support

For issues or questions:
1. Check logs: `docker-compose logs`
2. Run health check: `./deploy/scripts/health-check.sh`
3. Review this documentation
4. Check Cloudflare Tunnel status
5. Verify environment variables

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [rclone Documentation](https://rclone.org/docs/)
