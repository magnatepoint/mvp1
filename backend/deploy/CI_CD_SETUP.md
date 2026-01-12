# CI/CD Setup Guide

This guide will help you set up automatic deployment from GitHub to your Ubuntu server.

## Overview

When you push changes to the `main` branch, GitHub Actions will automatically:
1. SSH into your Ubuntu server
2. Pull the latest code
3. Rebuild Docker images
4. Run database migrations
5. Restart services
6. Run health checks

## Prerequisites

- GitHub repository with Actions enabled
- Ubuntu server with SSH access
- SSH key pair for authentication

## Step 1: Generate SSH Key Pair

On your local machine or GitHub Actions runner, generate an SSH key:

```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy

# This creates two files:
# - ~/.ssh/github_actions_deploy (private key)
# - ~/.ssh/github_actions_deploy.pub (public key)
```

## Step 2: Add Public Key to Ubuntu Server

Copy the public key to your server:

```bash
# Copy public key to server
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub user@your-server-ip

# Or manually add to ~/.ssh/authorized_keys on server
cat ~/.ssh/github_actions_deploy.pub | ssh user@your-server-ip "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

**On the server**, verify the key was added:

```bash
# On Ubuntu server
cat ~/.ssh/authorized_keys
```

## Step 3: Test SSH Connection

Test that you can SSH without a password:

```bash
ssh -i ~/.ssh/github_actions_deploy user@your-server-ip
```

## Step 4: Add GitHub Secrets

Go to your GitHub repository:
1. Navigate to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add the following secrets:

### Required Secrets:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SSH_PRIVATE_KEY` | Contents of the private key file | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `SERVER_HOST` | Your server IP or domain | `192.168.1.100` or `api.monytix.ai` |
| `SERVER_USER` | SSH username | `ubuntu` or `malla` |

### How to get SSH_PRIVATE_KEY:

```bash
# On your local machine
cat ~/.ssh/github_actions_deploy
# Copy the entire output (including BEGIN and END lines)
```

### How to add secrets:

1. Go to: `https://github.com/magnatepoint/mvp1/settings/secrets/actions`
2. Click **New repository secret**
3. For each secret:
   - **Name**: `SSH_PRIVATE_KEY` (or `SERVER_HOST`, `SERVER_USER`)
   - **Secret**: Paste the value
   - Click **Add secret**

## Step 5: Verify Workflow File

The workflow file is already created at:
`.github/workflows/deploy-backend.yml`

It will:
- Trigger on pushes to `main` branch (only for `backend/**` files)
- Allow manual triggers via GitHub UI
- Deploy automatically to your server

## Step 6: Test the Deployment

### Option 1: Push a test change

```bash
# Make a small change
echo "# Test" >> backend/README.md
git add backend/README.md
git commit -m "Test CI/CD deployment"
git push origin main
```

### Option 2: Manual trigger

1. Go to: `https://github.com/magnatepoint/mvp1/actions`
2. Click **Deploy Backend to Production**
3. Click **Run workflow** → **Run workflow**

## Step 7: Monitor Deployments

View deployment status:
- **GitHub Actions tab**: `https://github.com/magnatepoint/mvp1/actions`
- Check logs for any errors
- Verify services are running on server

## Troubleshooting

### SSH Connection Failed

**Error**: `Permission denied (publickey)`

**Solution**:
1. Verify public key is in `~/.ssh/authorized_keys` on server
2. Check file permissions: `chmod 600 ~/.ssh/authorized_keys`
3. Verify SSH user has correct permissions

### Deployment Fails

**Error**: `git pull failed`

**Solution**:
1. Ensure server has git configured
2. Check repository permissions
3. Verify you're in the correct directory

### Docker Build Fails

**Error**: `docker-compose build failed`

**Solution**:
1. Check Docker is running: `docker ps`
2. Verify `.env` file exists on server
3. Check Docker Compose version: `docker-compose --version`

### Health Check Fails

**Error**: `Health check failed`

**Solution**:
1. Check service logs: `docker-compose logs`
2. Verify all environment variables are set
3. Check database connection
4. Verify Redis is running

## Advanced Configuration

### Deploy Only on Tags

To deploy only when you create a tag:

```yaml
on:
  push:
    tags:
      - 'v*'
```

### Deploy to Staging First

Create a separate workflow for staging:

```yaml
on:
  push:
    branches:
      - develop
```

### Email Notifications

Add email notifications on failure:

```yaml
- name: Send email on failure
  if: failure()
  uses: dawidd6/action-send-mail@v3
  with:
    server_address: smtp.gmail.com
    server_port: 465
    username: ${{ secrets.EMAIL_USERNAME }}
    password: ${{ secrets.EMAIL_PASSWORD }}
    subject: Deployment Failed
    to: your-email@example.com
```

### Slack Notifications

Add Slack notifications:

```yaml
- name: Slack Notification
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Deployment ${{ job.status }}'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Security Best Practices

1. **Never commit private keys** - Always use GitHub Secrets
2. **Use SSH keys with passphrases** - More secure
3. **Limit SSH access** - Use firewall rules
4. **Rotate keys regularly** - Update keys periodically
5. **Use specific user** - Create a dedicated deployment user
6. **Monitor deployments** - Review logs regularly

## Rollback Procedure

If a deployment fails, rollback manually:

```bash
# On server
cd /opt/mvp-backend/backend
git checkout <previous-commit>
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

## Next Steps

1. ✅ Set up SSH keys
2. ✅ Add GitHub secrets
3. ✅ Test deployment
4. ✅ Monitor first deployment
5. ✅ Set up notifications (optional)

Your CI/CD pipeline is now ready! Every push to `main` will automatically deploy to your Ubuntu server.
