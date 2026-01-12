# Quick Fix: GitHub Secrets Error

## The Error

```
The ssh-private-key argument is empty. Maybe the secret has not been configured...
```

## Solution: Add the 3 Required Secrets

### Step 1: Go to GitHub Secrets Page

**Direct link:**
```
https://github.com/magnatepoint/mvp1/settings/secrets/actions
```

Or navigate:
1. Go to your repository: `https://github.com/magnatepoint/mvp1`
2. Click **Settings** (top menu)
3. Click **Secrets and variables** → **Actions**

### Step 2: Generate SSH Key (if you haven't)

**On your local machine:**

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_actions_deploy

# Press Enter when asked for passphrase (or set one)
```

### Step 3: Add Public Key to Server

```bash
# Copy public key to server
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub malla@your-server-ip

# Replace 'malla' with your username
# Replace 'your-server-ip' with your server IP
```

### Step 4: Get Private Key

```bash
# Display private key (copy everything)
cat ~/.ssh/github_actions_deploy
```

**IMPORTANT:** Copy the ENTIRE output including:
```
-----BEGIN OPENSSH PRIVATE KEY-----
... (all content) ...
-----END OPENSSH PRIVATE KEY-----
```

### Step 5: Add Secrets to GitHub

On the GitHub secrets page, click **"New repository secret"** and add:

#### Secret 1: SSH_PRIVATE_KEY
- **Name:** `SSH_PRIVATE_KEY` (exactly this, case-sensitive)
- **Secret:** Paste the entire private key from Step 4
- Click **Add secret**

#### Secret 2: SERVER_HOST
- **Name:** `SERVER_HOST`
- **Secret:** Your server IP or domain
  - Example: `api.monytix.ai`
  - Or: `192.168.1.100`
- Click **Add secret**

#### Secret 3: SERVER_USER
- **Name:** `SERVER_USER`
- **Secret:** Your SSH username
  - Example: `malla`
  - Or: `ubuntu`
- Click **Add secret**

### Step 6: Verify Secrets

After adding, you should see all 3 secrets listed:
- ✅ SSH_PRIVATE_KEY
- ✅ SERVER_HOST
- ✅ SERVER_USER

### Step 7: Test Again

1. Go to: `https://github.com/magnatepoint/mvp1/actions`
2. Click **"Deploy Backend to Production"**
3. Click **"Run workflow"** → **"Run workflow"**

## Common Issues

### "Secret not found"
- Check the secret name is exactly `SSH_PRIVATE_KEY` (case-sensitive)
- Make sure you're in the right repository

### "Permission denied"
- Public key not on server - run `ssh-copy-id` again
- Check `~/.ssh/authorized_keys` on server

### "Connection refused"
- Server might be down
- Check firewall settings
- Verify SERVER_HOST is correct

## Quick Test Command

Test SSH connection manually:

```bash
ssh -i ~/.ssh/github_actions_deploy malla@your-server-ip
```

If this works, the GitHub Actions should work too!
