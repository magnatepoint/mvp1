# Fix: SSH Passphrase Error

## The Error

```
Enter passphrase for (stdin):
Command failed: ssh-add
```

## Problem

Your SSH key has a passphrase, but GitHub Actions can't enter it interactively.

## Solution: Generate New Key Without Passphrase

**For CI/CD, use a key WITHOUT a passphrase** (it's stored securely in GitHub Secrets anyway).

### Step 1: Generate New SSH Key (No Passphrase)

**On your local machine:**

```bash
# Generate new key WITHOUT passphrase
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy -N ""

# The -N "" flag means no passphrase
# Press Enter when asked for file location (or use the path above)
```

**Important:** When prompted for passphrase, just press **Enter** (leave it empty).

### Step 2: Add Public Key to Server

```bash
# Copy public key to server
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub malla@your-server-ip

# Or manually:
cat ~/.ssh/github_actions_deploy.pub | ssh malla@your-server-ip "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### Step 3: Get the NEW Private Key

```bash
# Display the new private key (no passphrase)
cat ~/.ssh/github_actions_deploy
```

**Copy the ENTIRE output** including:
```
-----BEGIN OPENSSH PRIVATE KEY-----
... (all content) ...
-----END OPENSSH PRIVATE KEY-----
```

### Step 4: Update GitHub Secret

1. Go to: `https://github.com/magnatepoint/mvp1/settings/secrets/actions`
2. Find `SSH_PRIVATE_KEY` secret
3. Click **Update** (or delete and recreate)
4. Paste the NEW private key (from Step 3)
5. Click **Update secret**

### Step 5: Test SSH Connection

**Test that the new key works:**

```bash
# Test SSH connection (should work without asking for passphrase)
ssh -i ~/.ssh/github_actions_deploy malla@your-server-ip

# If it works, you're logged in without entering a passphrase
```

### Step 6: Test GitHub Actions

1. Go to: `https://github.com/magnatepoint/mvp1/actions`
2. Click **"Deploy Backend to Production"**
3. Click **"Run workflow"** → **"Run workflow"**

## Alternative: Keep Passphrase (Not Recommended)

If you MUST keep the passphrase, you can add it as a secret:

1. Add new secret: `SSH_PASSPHRASE`
2. Value: Your passphrase
3. The workflow will use it automatically

**But this is less secure and not recommended for CI/CD.**

## Why No Passphrase for CI/CD?

- GitHub Secrets are already encrypted and secure
- CI/CD needs automated access (can't enter passphrase interactively)
- The key is stored securely in GitHub Secrets
- You can rotate/revoke the key anytime

## Security Best Practices

1. ✅ Use dedicated SSH key for CI/CD (not your personal key)
2. ✅ No passphrase for CI/CD keys
3. ✅ Store key securely in GitHub Secrets
4. ✅ Rotate keys regularly (every 6-12 months)
5. ✅ Limit server access (firewall rules)
6. ✅ Monitor deployments

## Quick Commands Summary

```bash
# 1. Generate key without passphrase
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_actions_deploy -N ""

# 2. Add to server
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub malla@your-server-ip

# 3. Get private key for GitHub
cat ~/.ssh/github_actions_deploy

# 4. Test connection
ssh -i ~/.ssh/github_actions_deploy malla@your-server-ip
```

After updating the secret with the new key (no passphrase), the workflow should work!
