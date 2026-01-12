# GitHub Secrets Setup - Step by Step

## Quick Fix for "ssh-private-key argument is empty"

This error means the `SSH_PRIVATE_KEY` secret hasn't been added to GitHub yet. Follow these steps:

## Step 1: Generate SSH Key (if you don't have one)

**On your local machine or on the Ubuntu server:**

```bash
# Generate SSH key for GitHub Actions
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy

# Press Enter when asked for passphrase (or set one if you prefer)
```

This creates:
- `~/.ssh/github_actions_deploy` (private key - for GitHub)
- `~/.ssh/github_actions_deploy.pub` (public key - for server)

## Step 2: Add Public Key to Ubuntu Server

**Copy the public key to your server:**

```bash
# Option A: Using ssh-copy-id
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub user@your-server-ip

# Option B: Manual copy
cat ~/.ssh/github_actions_deploy.pub | ssh user@your-server-ip "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

**On the server, verify it was added:**

```bash
# SSH into your server
ssh user@your-server-ip

# Check authorized_keys
cat ~/.ssh/authorized_keys | grep github-actions-deploy
```

## Step 3: Get the Private Key Content

**On your local machine:**

```bash
# Display the private key (copy everything including BEGIN and END lines)
cat ~/.ssh/github_actions_deploy
```

**IMPORTANT:** Copy the ENTIRE output, including:
```
-----BEGIN OPENSSH PRIVATE KEY-----
... (all the content) ...
-----END OPENSSH PRIVATE KEY-----
```

## Step 4: Add Secrets to GitHub

1. **Go to your repository secrets page:**
   ```
   https://github.com/magnatepoint/mvp1/settings/secrets/actions
   ```

2. **Click "New repository secret"**

3. **Add these 3 secrets one by one:**

### Secret 1: SSH_PRIVATE_KEY

- **Name:** `SSH_PRIVATE_KEY`
- **Secret:** Paste the entire private key content (from Step 3)
- Click **Add secret**

### Secret 2: SERVER_HOST

- **Name:** `SERVER_HOST`
- **Secret:** Your server IP or domain
  - Example: `api.monytix.ai`
  - Or: `192.168.1.100`
- Click **Add secret**

### Secret 3: SERVER_USER

- **Name:** `SERVER_USER`
- **Secret:** Your SSH username
  - Example: `ubuntu`
  - Or: `malla`
- Click **Add secret**

## Step 5: Verify Secrets Are Added

After adding all 3 secrets, you should see:
- ✅ SSH_PRIVATE_KEY
- ✅ SERVER_HOST
- ✅ SERVER_USER

## Step 6: Test the Connection

**Test SSH connection manually first:**

```bash
# Test SSH with the key
ssh -i ~/.ssh/github_actions_deploy user@your-server-ip

# If it works, you should be logged in without password
```

## Step 7: Trigger Deployment

**Option A: Manual trigger (recommended for first test)**

1. Go to: `https://github.com/magnatepoint/mvp1/actions`
2. Click **Deploy Backend to Production**
3. Click **Run workflow** → **Run workflow**

**Option B: Push a change**

```bash
# Make a small change
echo "# Test" >> backend/README.md
git add backend/README.md
git commit -m "Test CI/CD"
git push origin main
```

## Troubleshooting

### Error: "ssh-private-key argument is empty"

**Cause:** Secret not added or wrong name

**Fix:**
1. Check secret name is exactly: `SSH_PRIVATE_KEY` (case-sensitive)
2. Verify secret exists: Go to Settings → Secrets → Actions
3. Re-add the secret if needed

### Error: "Permission denied (publickey)"

**Cause:** Public key not on server

**Fix:**
```bash
# Re-add public key to server
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub user@your-server-ip

# Or manually
cat ~/.ssh/github_actions_deploy.pub | ssh user@your-server-ip "cat >> ~/.ssh/authorized_keys"
```

### Error: "Host key verification failed"

**Cause:** Server not in known_hosts

**Fix:** The workflow already handles this with `ssh-keyscan`, but if it fails:
```bash
# Add server to known_hosts manually
ssh-keyscan -H your-server-ip >> ~/.ssh/known_hosts
```

### Error: "git pull failed"

**Cause:** Server doesn't have git access or wrong directory

**Fix:**
```bash
# On server, verify
cd /opt/mvp-backend/backend
git remote -v
git pull origin main  # Should work manually
```

## Quick Checklist

- [ ] SSH key generated (`~/.ssh/github_actions_deploy`)
- [ ] Public key added to server (`~/.ssh/authorized_keys`)
- [ ] Private key copied (entire content with BEGIN/END)
- [ ] `SSH_PRIVATE_KEY` secret added to GitHub
- [ ] `SERVER_HOST` secret added to GitHub
- [ ] `SERVER_USER` secret added to GitHub
- [ ] SSH connection tested manually
- [ ] Workflow triggered (manual or push)

## Security Notes

1. **Never commit private keys** - Always use GitHub Secrets
2. **Use dedicated SSH key** - Don't reuse your personal SSH key
3. **Rotate keys regularly** - Update keys every 6-12 months
4. **Limit server access** - Use firewall rules
5. **Monitor deployments** - Review GitHub Actions logs

## Need Help?

If you're still having issues:

1. Check GitHub Actions logs: `https://github.com/magnatepoint/mvp1/actions`
2. Verify all 3 secrets are set correctly
3. Test SSH connection manually first
4. Check server logs: `docker-compose logs` on server
