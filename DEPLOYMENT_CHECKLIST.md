# Deployment Checklist - Fix API Access Issues

## ✅ Issues Found

1. **Supabase Redirect URL is wrong** - Missing `/auth/` in path
2. **Backend CORS** - `FRONTEND_ORIGIN` missing in Production environment
3. **Cloudflare Tunnel** - May not be running (API not accessible)

## 🔧 Fixes Required

### 1. Fix Supabase Redirect URL

**In Supabase Dashboard:**
1. Go to Authentication → URL Configuration
2. Find `https://mvp.monytix.ai/callback` in Redirect URLs
3. **Remove** it
4. **Add** new URL: `https://mvp.monytix.ai/auth/callback`
5. Click "Save changes"

**In Cloudflare Pages (Frontend):**
1. Go to Settings → Environment Variables
2. Update `NEXT_PUBLIC_SUPABASE_REDIRECT_URL`:
   - **Old:** `http://mvp.monytix.ai/...` (HTTP + wrong path)
   - **New:** `https://mvp.monytix.ai/auth/callback` (HTTPS + correct path)
3. **Redeploy** the frontend (required for `NEXT_PUBLIC_*` variables)

### 2. Fix Backend CORS Configuration

**In Coolify (Backend):**
1. Go to your backend application
2. Navigate to Settings → Environment Variables
3. **Production Environment Variables** section:
   - Add: `FRONTEND_ORIGIN=https://mvp.monytix.ai`
   - (Currently only in Preview Deployments)
4. Save and **restart the backend service**

### 3. Verify Cloudflare Tunnel is Running

**On your backend server, check tunnel status:**

```bash
# If using systemd
sudo systemctl status cloudflare-tunnel

# If using Docker
docker ps | grep cloudflare
```

**If not running, start it:**

```bash
# Systemd
sudo systemctl start cloudflare-tunnel
sudo systemctl enable cloudflare-tunnel

# Docker
cd /path/to/backend
docker-compose -f deploy/cloudflare/docker-compose.tunnel.yml up -d
```

**Test API accessibility:**

```bash
# Should return {"status":"ok"}
curl https://api.monytix.ai/health
```

### 4. Verify DNS Configuration

**In Cloudflare Dashboard:**
1. Go to DNS settings
2. Verify `api.monytix.ai` has a CNAME record:
   - **Type:** CNAME
   - **Name:** `api`
   - **Target:** `mvp-backend-tunnel.cfargotunnel.com` (or your tunnel's hostname)
   - **Proxy status:** Proxied (orange cloud)

## 📋 Complete Checklist

- [ ] Supabase: Update redirect URL to `https://mvp.monytix.ai/auth/callback`
- [ ] Cloudflare Pages: Update `NEXT_PUBLIC_SUPABASE_REDIRECT_URL` to `https://mvp.monytix.ai/auth/callback`
- [ ] Cloudflare Pages: Redeploy frontend after env var change
- [ ] Coolify: Add `FRONTEND_ORIGIN=https://mvp.monytix.ai` to **Production** environment
- [ ] Coolify: Restart backend service after env var change
- [ ] Backend Server: Verify Cloudflare tunnel is running
- [ ] Backend Server: Test `curl https://api.monytix.ai/health` works
- [ ] Cloudflare DNS: Verify `api.monytix.ai` CNAME record exists

## 🧪 Testing After Fixes

1. **Test API directly:**
   ```bash
   curl https://api.monytix.ai/health
   ```

2. **Test from browser:**
   - Open `https://api.monytix.ai/health` in browser
   - Should see JSON response

3. **Test frontend:**
   - Open `https://mvp.monytix.ai`
   - Check browser console for API calls
   - Should see successful requests, not "Failed to fetch"

4. **Test authentication:**
   - Try Google OAuth sign-in
   - Should redirect to `/auth/callback` successfully

## 🔍 Debugging

If still not working after all fixes:

1. **Check browser console** for specific error messages
2. **Check backend logs** for incoming requests
3. **Check tunnel logs** for connection issues:
   ```bash
   sudo journalctl -u cloudflare-tunnel -n 100
   # or
   docker logs mvp-cloudflare-tunnel --tail 100
   ```
4. **Verify environment variables** are actually set:
   - Backend: `echo $FRONTEND_ORIGIN`
   - Frontend: Check Cloudflare Pages build logs for env vars
