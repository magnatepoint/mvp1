# Manual Deployment Guide

Since CI/CD has network connectivity issues, use this manual deployment process.

## Quick Deploy

### Option 1: Deploy from Your Local Machine

**From your Mac (in the mvp directory):**

```bash
cd /Users/santosh/coding/mvp/backend

# Set server details
export SERVER_USER=malla
export SERVER_HOST=your-server-ip

# Run deployment
./deploy/manual-deploy.sh
```

The script will:
- SSH into your server
- Pull latest code
- Rebuild Docker images
- Run migrations
- Restart services
- Run health checks

### Option 2: Deploy Directly on Server

**SSH into your server first:**

```bash
ssh malla@your-server-ip
cd /opt/mvp-backend/backend
./deploy/manual-deploy.sh
```

## Step-by-Step Manual Process

If you prefer to do it step by step:

### On Your Server:

```bash
# 1. SSH into server
ssh malla@your-server-ip

# 2. Navigate to backend directory
cd /opt/mvp-backend/backend

# 3. Pull latest code
git pull origin main

# 4. Rebuild images
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache

# 5. Run migrations (optional)
./deploy/scripts/run-migrations.sh

# 6. Restart services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 7. Check status
docker-compose ps

# 8. Check health
./deploy/scripts/health-check.sh
```

## Quick Commands Reference

### Check Services
```bash
docker-compose ps
docker-compose logs -f
```

### Restart Single Service
```bash
docker-compose restart backend
docker-compose restart celery-worker
```

### View Logs
```bash
docker-compose logs -f backend
docker-compose logs -f celery-worker
docker-compose logs -f redis
```

### Stop All Services
```bash
docker-compose down
```

### Start All Services
```bash
docker-compose up -d
```

## Deployment Checklist

Before deploying:

- [ ] Code is committed and pushed to GitHub
- [ ] `.env` file is configured on server
- [ ] Server has internet access
- [ ] Docker is running on server

After deploying:

- [ ] Services are running: `docker-compose ps`
- [ ] Health check passes: `./deploy/scripts/health-check.sh`
- [ ] API is accessible: `curl http://localhost:8000/health`
- [ ] Check logs for errors: `docker-compose logs`

## Troubleshooting

### "git pull" fails
```bash
# Check git remote
git remote -v

# If needed, set remote
git remote set-url origin https://github.com/magnatepoint/mvp1.git
```

### Docker build fails
```bash
# Check Docker is running
docker ps

# Check disk space
df -h

# Clean up old images
docker system prune -a
```

### Services won't start
```bash
# Check logs
docker-compose logs

# Check .env file
cat .env

# Verify all required variables are set
```

## When to Use Manual Deploy

- ✅ Network connectivity issues with CI/CD
- ✅ Need more control over deployment
- ✅ Testing changes before full deployment
- ✅ Quick hotfixes
- ✅ Debugging deployment issues

## Future: Re-enable CI/CD

Once network issues are resolved:

1. Fix `SERVER_HOST` to use public IP or Cloudflare Tunnel
2. Test GitHub Actions workflow
3. Re-enable automatic deployments

For now, manual deployment works perfectly fine!
