# Quick Server Update Guide

## Update Backend with Latest Code

```bash
# SSH into your server
ssh malla@192.168.68.13

# Navigate to backend directory
cd /opt/mvp-backend/backend

# Pull latest code
git pull origin main

# Rebuild and restart services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache backend
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Check logs to verify it's running
docker-compose logs -f backend

# Test the endpoint
curl https://api.monytix.ai/v1/spendsense/kpis -H "Authorization: Bearer YOUR_TOKEN"
```

## Verify Routes

After updating, you can verify the routes are registered:

```bash
# Check if the route exists
curl https://api.monytix.ai/docs

# Or test directly (will return 401 if not authenticated, but confirms route exists)
curl https://api.monytix.ai/v1/spendsense/kpis
```

## Common Issues

1. **404 Not Found**: Backend hasn't been updated with latest code
2. **500 Internal Server Error**: Database connection issue or application error
3. **401 Unauthorized**: Authentication token issue (this is expected if not authenticated)
