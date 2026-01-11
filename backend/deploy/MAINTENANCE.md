# MVP Backend Maintenance Guide

Common maintenance tasks and procedures for the MVP backend production deployment.

## Table of Contents

- [Regular Maintenance](#regular-maintenance)
- [Updating the Application](#updating-the-application)
- [Backup Management](#backup-management)
- [Log Management](#log-management)
- [Database Maintenance](#database-maintenance)
- [Service Restarts](#service-restarts)
- [Monitoring](#monitoring)

## Regular Maintenance

### Daily Tasks

- **Check service health:**
  ```bash
  ./deploy/scripts/health-check.sh
  ```

- **Review logs for errors:**
  ```bash
  docker-compose logs --tail=100 | grep -i error
  ```

- **Verify backups are running:**
  ```bash
  journalctl -u backup.timer -u backup.service --since today
  ```

### Weekly Tasks

- **Review backup retention:**
  ```bash
  rclone lsf <remote-name>:mvp-backups/ | wc -l
  ```

- **Check disk space:**
  ```bash
  df -h
  docker system df
  ```

- **Review application logs:**
  ```bash
  tail -n 1000 logs/*.log | grep -i error
  ```

### Monthly Tasks

- **Update dependencies:**
  ```bash
  docker-compose build --no-cache
  ```

- **Review and clean old backups:**
  ```bash
  # List backups older than 30 days
  rclone lsf <remote-name>:mvp-backups/ --format "t" | while read file; do
    # Check age and delete if needed
  done
  ```

- **Database maintenance:**
  ```bash
  # Vacuum and analyze (if using PostgreSQL)
  psql $POSTGRES_URL -c "VACUUM ANALYZE;"
  ```

## Updating the Application

### Standard Update Process

1. **Pull latest code:**
   ```bash
   cd /opt/mvp-backend
   git pull
   ```

2. **Review changes:**
   ```bash
   git log HEAD..origin/main
   ```

3. **Backup before update:**
   ```bash
   ./deploy/scripts/backup.sh
   ```

4. **Update environment if needed:**
   ```bash
   # Check if .env needs updates
   diff .env.production.example .env
   ```

5. **Deploy:**
   ```bash
   ./deploy/deploy.sh
   ```

6. **Verify:**
   ```bash
   ./deploy/scripts/health-check.sh
   ```

### Rolling Back

If an update causes issues:

1. **Stop services:**
   ```bash
   docker-compose down
   ```

2. **Restore from backup:**
   ```bash
   ./deploy/scripts/restore.sh
   # Select backup from before update
   ```

3. **Restart services:**
   ```bash
   docker-compose up -d
   ```

4. **Revert code:**
   ```bash
   git checkout <previous-commit>
   ./deploy/deploy.sh
   ```

## Backup Management

### Manual Backup

```bash
./deploy/scripts/backup.sh
```

### Restore from Backup

```bash
./deploy/scripts/restore.sh
```

### List Backups

**Local backups:**
```bash
ls -lh backups/
```

**Cloud backups:**
```bash
rclone lsf <remote-name>:mvp-backups/
```

### Delete Old Backups

**Local:**
```bash
# Delete backups older than 7 days
find backups/ -name "*.tar.gz" -mtime +7 -delete
```

**Cloud:**
```bash
# List old backups
rclone lsf <remote-name>:mvp-backups/ --format "t" | head -20

# Delete specific backup
rclone delete <remote-name>:mvp-backups/mvp-backup-YYYYMMDD_HHMMSS.tar.gz
```

### Backup Verification

Test backup integrity:

```bash
# Download and verify
rclone copy <remote-name>:mvp-backups/latest-backup.tar.gz /tmp/
tar -tzf /tmp/latest-backup.tar.gz > /dev/null && echo "Backup is valid"
```

## Log Management

### View Logs

**All services:**
```bash
docker-compose logs -f
```

**Specific service:**
```bash
docker-compose logs -f backend
docker-compose logs -f celery-worker
docker-compose logs -f redis
```

**Application logs:**
```bash
tail -f logs/*.log
```

### Log Rotation

Logs are automatically rotated via:
- Docker log driver (max 10MB, 3 files)
- System logrotate (daily, 7 days retention)

Manual rotation:
```bash
./deploy/scripts/log-rotation.sh
```

### Clean Old Logs

```bash
# Application logs
find logs/ -name "*.log" -mtime +7 -delete

# Docker logs
docker system prune -f
```

## Database Maintenance

### Run Migrations

```bash
./deploy/scripts/run-migrations.sh
```

### Database Backup

**PostgreSQL:**
```bash
pg_dump $POSTGRES_URL > backup_$(date +%Y%m%d).sql
```

### Database Optimization

**Vacuum and analyze:**
```bash
psql $POSTGRES_URL -c "VACUUM ANALYZE;"
```

**Check table sizes:**
```bash
psql $POSTGRES_URL -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"
```

## Service Restarts

### Restart All Services

```bash
docker-compose restart
```

### Restart Specific Service

```bash
docker-compose restart backend
docker-compose restart celery-worker
docker-compose restart redis
```

### Graceful Restart

```bash
# Stop
docker-compose stop backend

# Start
docker-compose start backend
```

### Systemd Service Restart

```bash
sudo systemctl restart backend
sudo systemctl restart cloudflare-tunnel
```

## Monitoring

### Health Checks

**Automated:**
```bash
./deploy/scripts/health-check.sh
```

**Manual API check:**
```bash
curl http://localhost:8000/health
```

**Redis check:**
```bash
docker exec mvp-redis redis-cli ping
```

### Service Status

**Docker services:**
```bash
docker-compose ps
docker ps
```

**Systemd services:**
```bash
sudo systemctl status backend
sudo systemctl status cloudflare-tunnel
sudo systemctl status backup.timer
```

### Resource Usage

**Container resources:**
```bash
docker stats
```

**Disk usage:**
```bash
df -h
du -sh /opt/mvp-backend/*
```

**Memory usage:**
```bash
free -h
docker stats --no-stream
```

### Cloudflare Tunnel Status

```bash
cloudflared tunnel list
cloudflared tunnel info <tunnel-name>
```

## Troubleshooting Common Issues

### Services Won't Start

1. Check Docker:
   ```bash
   docker ps -a
   docker-compose logs
   ```

2. Check environment:
   ```bash
   cat .env | grep -v "^#"
   ```

3. Check ports:
   ```bash
   netstat -tulpn | grep 8000
   ```

### High Memory Usage

1. Check container limits:
   ```bash
   docker stats
   ```

2. Restart services:
   ```bash
   docker-compose restart
   ```

3. Clean up:
   ```bash
   docker system prune -f
   ```

### Backup Failures

1. Check rclone:
   ```bash
   rclone lsd <remote-name>:
   ```

2. Check GPG (if using encryption):
   ```bash
   gpg --list-keys
   ```

3. Check logs:
   ```bash
   journalctl -u backup.service -n 50
   ```

### Database Connection Issues

1. Test connection:
   ```bash
   psql $POSTGRES_URL -c "SELECT 1;"
   ```

2. Check network:
   ```bash
   docker network ls
   docker network inspect mvp-backend_mvp-network
   ```

### Redis Issues

1. Check Redis:
   ```bash
   docker exec mvp-redis redis-cli ping
   docker exec mvp-redis redis-cli INFO
   ```

2. Check memory:
   ```bash
   docker exec mvp-redis redis-cli INFO memory
   ```

## Performance Tuning

### Increase Workers

Edit `docker-compose.prod.yml`:
```yaml
backend:
  command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

### Increase Celery Concurrency

Edit `docker-compose.prod.yml`:
```yaml
celery-worker:
  command: celery -A app.celery_app worker --loglevel=info --concurrency=8
```

### Redis Memory Limits

Edit `docker-compose.yml`:
```yaml
redis:
  command: redis-server --maxmemory 1gb --maxmemory-policy allkeys-lru
```

## Security Updates

### Update Dependencies

```bash
# Update requirements
pip-compile requirements.in  # If using pip-tools
# Or manually update requirements.txt

# Rebuild images
docker-compose build --no-cache
docker-compose up -d
```

### Update System Packages

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### Update Docker

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

## Emergency Procedures

### Complete Service Failure

1. **Stop all services:**
   ```bash
   docker-compose down
   ```

2. **Check logs:**
   ```bash
   docker-compose logs > emergency_logs.txt
   ```

3. **Restore from backup:**
   ```bash
   ./deploy/scripts/restore.sh
   ```

4. **Restart services:**
   ```bash
   docker-compose up -d
   ```

### Data Loss Recovery

1. **Stop services immediately**
2. **Identify last good backup**
3. **Restore from backup**
4. **Verify data integrity**
5. **Restart services**

### Security Incident

1. **Isolate affected services**
2. **Review logs for suspicious activity**
3. **Change all credentials**
4. **Restore from clean backup if needed**
5. **Update security configurations**

## Maintenance Schedule

### Recommended Schedule

- **Daily:** Health checks, log review
- **Weekly:** Backup verification, disk space check
- **Monthly:** Dependency updates, database optimization
- **Quarterly:** Security audit, performance review

### Automated Tasks

- Daily backups (2 AM via systemd timer)
- Log rotation (via logrotate)
- Health monitoring (via health-check script)

## Contact and Support

For critical issues:
1. Check logs first
2. Review this guide
3. Check service status
4. Restore from backup if needed
