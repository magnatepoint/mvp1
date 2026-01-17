# Troubleshooting API Access Issues

## Problem
Frontend at `mvp.monytix.ai` cannot reach backend at `https://api.monytix.ai`, showing "Failed to fetch" errors.

## Backend Status
✅ Backend is running on port 8001 and responding to health checks
✅ Backend logs show: `Uvicorn running on http://0.0.0.0:8001`

## Likely Issue: Cloudflare Tunnel Not Running

The backend is exposed via Cloudflare Tunnel. If the tunnel isn't running, `https://api.monytix.ai` won't be accessible.

### Check Cloudflare Tunnel Status

**If using systemd:**
```bash
sudo systemctl status cloudflare-tunnel
```

**If using Docker:**
```bash
docker ps | grep cloudflare
# or
docker-compose -f deploy/cloudflare/docker-compose.tunnel.yml ps
```

**Check tunnel logs:**
```bash
# Systemd
sudo journalctl -u cloudflare-tunnel -n 50

# Docker
docker logs mvp-cloudflare-tunnel
# or
docker-compose -f deploy/cloudflare/docker-compose.tunnel.yml logs
```

### Start/Restart Cloudflare Tunnel

**If using systemd:**
```bash
sudo systemctl start cloudflare-tunnel
# or restart
sudo systemctl restart cloudflare-tunnel
```

**If using Docker:**
```bash
cd /path/to/backend
docker-compose -f deploy/cloudflare/docker-compose.tunnel.yml up -d
```

### Verify Tunnel Configuration

1. **Check tunnel config file:**
   ```bash
   cat deploy/cloudflare/config.yml
   ```
   
   Should show:
   ```yaml
   tunnel: mvp-backend-tunnel
   ingress:
     - hostname: api.monytix.ai
       service: http://localhost:8001
   ```

2. **Check credentials file exists:**
   ```bash
   ls -la deploy/cloudflare/credentials.json
   ```

3. **Test tunnel manually:**
   ```bash
   cloudflared tunnel run mvp-backend-tunnel
   ```
   
   This will show connection status and any errors.

### Verify DNS Configuration

1. **Check DNS records in Cloudflare Dashboard:**
   - Go to Cloudflare Dashboard → Your Domain → DNS
   - Verify `api.monytix.ai` has a CNAME record pointing to the tunnel
   - Should be: `api.monytix.ai` → `mvp-backend-tunnel.cfargotunnel.com` (or similar)

2. **Test DNS resolution:**
   ```bash
   dig api.monytix.ai
   # or
   nslookup api.monytix.ai
   ```

### Verify Backend CORS Configuration

Even if the tunnel is working, CORS issues can prevent requests.

1. **Check `FRONTEND_ORIGIN` environment variable:**
   ```bash
   # In backend container/server
   echo $FRONTEND_ORIGIN
   ```
   
   Should include: `https://mvp.monytix.ai`

2. **Update if needed:**
   ```bash
   # In Coolify: Settings → Environment Variables
   FRONTEND_ORIGIN=https://mvp.monytix.ai
   ```
   
   Then restart the backend service.

3. **Verify CORS in backend logs:**
   - Look for CORS-related errors in backend logs
   - Check if requests are reaching the backend but being blocked

### Test API Access Directly

1. **From the server (should work):**
   ```bash
   curl http://localhost:8001/health
   ```

2. **From external (should work if tunnel is running):**
   ```bash
   curl https://api.monytix.ai/health
   ```

3. **From browser:**
   - Open `https://api.monytix.ai/health` in a browser
   - Should return JSON response

### Common Issues and Solutions

**Issue: Tunnel not running**
- **Solution:** Start the tunnel service (see above)

**Issue: Invalid tunnel credentials**
- **Solution:** Regenerate tunnel token in Cloudflare Dashboard and update credentials file

**Issue: DNS not configured**
- **Solution:** Add CNAME record in Cloudflare DNS pointing to tunnel

**Issue: Wrong port in tunnel config**
- **Solution:** Verify config shows `service: http://localhost:8001` (not 8000)

**Issue: Backend not accessible from tunnel**
- **Solution:** Ensure backend is running and accessible on `localhost:8001`

**Issue: CORS blocking requests**
- **Solution:** Update `FRONTEND_ORIGIN` to include `https://mvp.monytix.ai` and restart backend

### Quick Diagnostic Commands

```bash
# 1. Check if backend is running
curl http://localhost:8001/health

# 2. Check if tunnel is running
sudo systemctl status cloudflare-tunnel
# or
docker ps | grep cloudflare

# 3. Check tunnel logs for errors
sudo journalctl -u cloudflare-tunnel -n 100
# or
docker logs mvp-cloudflare-tunnel --tail 100

# 4. Test external access
curl https://api.monytix.ai/health

# 5. Check DNS
dig api.monytix.ai
```

### Expected Behavior

When everything is working:
- ✅ `curl http://localhost:8001/health` returns `{"status":"ok"}`
- ✅ `curl https://api.monytix.ai/health` returns `{"status":"ok"}`
- ✅ Frontend can make API calls without "Failed to fetch" errors
- ✅ Browser console shows successful API requests
