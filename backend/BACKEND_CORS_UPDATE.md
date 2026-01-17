# Backend CORS Configuration Update for Cloudflare Pages

This guide explains how to update the backend CORS configuration to support the Cloudflare Pages frontend deployment.

## Overview

The backend uses the `FRONTEND_ORIGIN` environment variable to configure CORS (Cross-Origin Resource Sharing). With the new CORS configuration, you can specify multiple frontend origins separated by commas.

## Update Steps

### 1. Update Backend Environment Variable

In your backend deployment (Coolify, Docker, or server), update the `FRONTEND_ORIGIN` environment variable to include your Cloudflare Pages domain:

**Option A: Single Frontend (Replace existing)**
```bash
FRONTEND_ORIGIN=https://mvp.monytix.ai
```

**Option B: Multiple Frontends (Comma-separated)**
```bash
FRONTEND_ORIGIN=https://mvp.monytix.ai,https://your-other-domain.com
```

### 2. For Coolify Deployment

1. Go to your Coolify backend application
2. Navigate to **Environment Variables**
3. Find `FRONTEND_ORIGIN`
4. Update it to include your Cloudflare Pages domain:
   ```
   https://mvp.monytix.ai
   ```
   Or if you have multiple frontends:
   ```
   https://mvp.monytix.ai,https://app.monytix.ai
   ```
5. **Restart the backend service** for changes to take effect

### 3. For Docker/Docker Compose Deployment

1. Edit your `.env` file or environment configuration:
   ```bash
   FRONTEND_ORIGIN=https://mvp.monytix.ai
   ```

2. Restart the backend container:
   ```bash
   docker-compose restart backend
   # or
   docker restart <backend-container-name>
   ```

### 4. For Manual Server Deployment

1. Edit your backend `.env` file:
   ```bash
   nano backend/.env
   ```

2. Update the `FRONTEND_ORIGIN` variable:
   ```bash
   FRONTEND_ORIGIN=https://mvp.monytix.ai
   ```

3. Restart the backend service:
   ```bash
   # If using systemd
   sudo systemctl restart mvp-backend
   
   # If using Docker
   docker-compose restart backend
   ```

## Verification

After updating, verify the CORS configuration is working:

1. **Check backend logs** for CORS-related errors
2. **Test from browser console** on your Cloudflare Pages site:
   ```javascript
   fetch('https://api.monytix.ai/health', {
     method: 'GET',
     credentials: 'include'
   })
   .then(r => r.json())
   .then(console.log)
   .catch(console.error)
   ```

3. **Check Network tab** in browser DevTools:
   - Look for CORS errors in the console
   - Verify `Access-Control-Allow-Origin` header in response headers

## Current CORS Configuration

The backend now supports:
- **Multiple frontend origins** (comma-separated in `FRONTEND_ORIGIN`)
- **Automatic trailing slash variants** (both `https://domain.com` and `https://domain.com/`)
- **Mobile apps** (allows `*` in production for iOS/Android/Flutter apps)
- **Development origins** (localhost variants for local development)

## Security Notes

- In production, the backend allows all origins (`*`) for mobile apps, but explicitly lists web frontend origins
- Security is primarily handled through authentication tokens (JWT), not CORS
- CORS is a browser security feature; mobile apps don't enforce CORS

## Troubleshooting

### CORS Errors Still Occurring

1. **Verify environment variable is set correctly:**
   ```bash
   # In backend container/server
   echo $FRONTEND_ORIGIN
   ```

2. **Check backend logs** for CORS configuration:
   ```bash
   docker logs <backend-container> | grep -i cors
   ```

3. **Ensure backend was restarted** after changing environment variables

4. **Verify the exact domain** matches (including protocol `https://` and no trailing slash in config)

### Multiple Frontend Origins

If you have multiple frontend deployments (e.g., staging and production), you can list them all:
```bash
FRONTEND_ORIGIN=https://mvp.monytix.ai,https://staging.monytix.ai,https://app.monytix.ai
```

The backend will allow CORS requests from all listed origins.
