# SSH Connection Troubleshooting

## Error: "Network is unreachable"

This means GitHub Actions can't reach your server. Here's how to fix it:

## Step 1: Check Your SERVER_HOST Secret

**What is SERVER_HOST set to?**

1. Go to: `https://github.com/magnatepoint/mvp1/settings/secrets/actions`
2. Check the value of `SERVER_HOST`

**Common issues:**
- ❌ Private IP: `192.168.1.100` (won't work from internet)
- ❌ Localhost: `localhost` or `127.0.0.1` (won't work)
- ✅ Public IP: `123.45.67.89` (should work)
- ✅ Domain: `api.monytix.ai` (should work if DNS is correct)

## Step 2: Find Your Server's Public IP

**On your Ubuntu server, run:**

```bash
# Get public IP
curl ifconfig.me
# Or
curl ipinfo.io/ip
# Or
hostname -I | awk '{print $1}'  # This shows local IP, not public
```

**If you get a private IP (192.168.x.x or 10.x.x.x):**
- Your server is behind a router/NAT
- You need to set up port forwarding OR use Cloudflare Tunnel

## Step 3: Solutions

### Solution A: Use Public IP (If Available)

1. **Get your router's public IP:**
   - Check your router admin panel
   - Or use: `curl ifconfig.me` from a device on your network

2. **Set up port forwarding:**
   - Router admin → Port Forwarding
   - Forward external port 22 → Your server's private IP:22
   - Update `SERVER_HOST` with router's public IP

3. **Update GitHub secret:**
   - `SERVER_HOST` = Your router's public IP

### Solution B: Use Cloudflare Tunnel for SSH (Recommended)

Since you're already using Cloudflare Tunnel, expose SSH through it:

1. **Update Cloudflare Tunnel config on server:**

   Edit `/opt/mvp-backend/backend/deploy/cloudflare/config.yml`:

   ```yaml
   tunnel: back.monytix.ai
   credentials-file: /etc/cloudflared/credentials.json

   ingress:
     # SSH through Cloudflare Tunnel
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

2. **Create DNS record for SSH:**
   ```bash
   # On your server or via Cloudflare dashboard
   cloudflared tunnel route dns back.monytix.ai ssh.monytix.ai
   ```

3. **Update GitHub secret:**
   - `SERVER_HOST` = `ssh.monytix.ai`
   - Or use the tunnel's direct connection

4. **Restart Cloudflare Tunnel:**
   ```bash
   docker-compose restart cloudflare-tunnel
   ```

### Solution C: Use GitHub Self-Hosted Runner (Best for Private Networks)

Run GitHub Actions directly on your server:

1. **Install runner on your server:**
   ```bash
   # Download runner
   mkdir actions-runner && cd actions-runner
   curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
   tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
   
   # Configure
   ./config.sh --url https://github.com/magnatepoint/mvp1 --token YOUR_TOKEN
   
   # Install as service
   sudo ./svc.sh install
   sudo ./svc.sh start
   ```

2. **Update workflow to use self-hosted runner:**
   ```yaml
   runs-on: self-hosted
   ```

## Step 4: Test Connection

**From your local machine, test:**

```bash
# Test with the same credentials GitHub Actions will use
ssh -i ~/.ssh/github_actions_deploy malla@your-server-host
```

**If this works locally but not from GitHub Actions:**
- Server is on private network
- Need public IP or Cloudflare Tunnel

## Quick Diagnostic

**Run this on your server to check network:**

```bash
# Check if server has public IP
curl ifconfig.me

# Check if SSH is listening
sudo netstat -tlnp | grep :22

# Check firewall
sudo ufw status
sudo ufw allow 22/tcp  # If not already allowed
```

## Recommended: Cloudflare Tunnel for SSH

Since you're already using Cloudflare Tunnel, this is the easiest solution:

1. Add SSH ingress to tunnel config
2. Create DNS record: `ssh.monytix.ai`
3. Update `SERVER_HOST` = `ssh.monytix.ai`
4. Test and deploy!

This way, you don't need to expose port 22 publicly.
