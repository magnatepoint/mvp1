# Fix: "Network is unreachable" Error

## The Error

```
ssh: connect to host *** port 22: Network is unreachable
Error: Process completed with exit code 255
```

## Problem

GitHub Actions can't reach your server because:
- Server is on a private network (not accessible from internet)
- Server IP is behind a firewall/NAT
- Port 22 (SSH) is blocked

## Solutions

### Solution 1: Use Public IP or Domain (Recommended)

If your server has a public IP or domain:

1. **Check your SERVER_HOST secret:**
   - Go to: `https://github.com/magnatepoint/mvp1/settings/secrets/actions`
   - Check `SERVER_HOST` value
   - It should be a **public IP** or **domain name** (not `192.168.x.x` or `10.x.x.x`)

2. **If using domain (like `api.monytix.ai`):**
   - Make sure DNS points to your server's public IP
   - Use the domain in `SERVER_HOST` secret

3. **If using IP:**
   - Find your server's public IP:
     ```bash
     # On your server
     curl ifconfig.me
     # Or
     curl ipinfo.io/ip
     ```
   - Update `SERVER_HOST` secret with the public IP

### Solution 2: Expose SSH Through Cloudflare Tunnel

Since you're using Cloudflare Tunnel, you can expose SSH through it:

1. **Add SSH to Cloudflare Tunnel config:**

   Edit `deploy/cloudflare/config.yml` on your server:

   ```yaml
   tunnel: back.monytix.ai
   credentials-file: /etc/cloudflared/credentials.json

   ingress:
     # SSH through tunnel
     - hostname: ssh.monytix.ai
       service: ssh://localhost:22
     
     # Backend API
     - hostname: api.monytix.ai
       service: http://localhost:8000
       originRequest:
         noHappyEyeballs: true
         keepAliveConnections: 100
         keepAliveTimeout: 90s
         httpHostHeader: api.monytix.ai
         http2Origin: true
         compressionQuality: 0

     - service: http_status:404
   ```

2. **Update GitHub secret:**
   - Change `SERVER_HOST` to: `ssh.monytix.ai`
   - Or use the tunnel's SSH endpoint

3. **Restart Cloudflare Tunnel:**
   ```bash
   docker-compose restart cloudflare-tunnel
   ```

### Solution 3: Use SSH Jump Host / Bastion

If you have a public server that can reach your private server:

1. SSH to public server first
2. Then SSH to private server from there

### Solution 4: Use GitHub Self-Hosted Runner (Advanced)

Run GitHub Actions on your own server:

1. Set up self-hosted runner on your server
2. Actions run directly on server (no SSH needed)

## Quick Check: Is Your Server Accessible?

**Test from your local machine:**

```bash
# Test SSH connection
ssh malla@your-server-ip

# If this works locally but not from GitHub Actions:
# - Server is on private network
# - Need public IP or Cloudflare Tunnel
```

**Test from internet:**

```bash
# Use an online service or another server
# Try to SSH to your server's public IP
```

## Recommended Fix

Since you're using Cloudflare Tunnel, the easiest solution is:

1. **Use your server's public IP or domain** in `SERVER_HOST` secret
2. **Make sure port 22 is open** in your firewall
3. **Or expose SSH through Cloudflare Tunnel** (Solution 2 above)

## Update SERVER_HOST Secret

1. Go to: `https://github.com/magnatepoint/mvp1/settings/secrets/actions`
2. Find `SERVER_HOST`
3. Update with:
   - Public IP (from `curl ifconfig.me` on server)
   - Or domain name (if DNS is configured)
   - Or Cloudflare Tunnel SSH endpoint

## Verify Server Accessibility

**On your server, check:**

```bash
# Check public IP
curl ifconfig.me

# Check if SSH is listening
sudo netstat -tlnp | grep :22

# Check firewall
sudo ufw status
# Make sure port 22 is allowed: sudo ufw allow 22
```

After fixing `SERVER_HOST` to use a public IP/domain, the workflow should work!
