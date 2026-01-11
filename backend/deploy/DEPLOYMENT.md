# Copying Code to Ubuntu Server

This guide covers different methods to transfer your backend code to your Ubuntu server.

## Prerequisites

- Ubuntu server with SSH access
- Your local machine with the code
- SSH key or password for the server

## Method 1: Using Git (Recommended)

If your code is in a Git repository, this is the easiest method:

### On Ubuntu Server:

```bash
# Install Git if not already installed
sudo apt-get update
sudo apt-get install -y git

# Clone your repository
cd /opt
sudo git clone <your-repo-url> mvp-backend
cd mvp-backend

# If using a private repo, set up SSH keys or use HTTPS with credentials
# For private repos with SSH:
# 1. Generate SSH key on server: ssh-keygen -t ed25519 -C "server@mvp"
# 2. Add public key to your Git provider (GitHub, GitLab, etc.)
# 3. Clone using SSH URL: git clone git@github.com:username/repo.git mvp-backend

# Set ownership
sudo chown -R $USER:$USER /opt/mvp-backend
```

### Update Code Later:

```bash
cd /opt/mvp-backend
git pull
```

## Method 2: Using SCP (Secure Copy)

Copy files directly from your local machine to the server:

### From Your Local Machine:

```bash
# Copy entire backend directory
scp -r backend/ user@your-server-ip:/opt/mvp-backend

# Or if you're in the mvp directory:
cd /Users/santosh/coding/mvp
scp -r backend/ user@your-server-ip:/opt/mvp-backend

# Example:
scp -r backend/ ubuntu@192.168.1.100:/opt/mvp-backend
```

### With SSH Key:

```bash
# If using SSH key
scp -i ~/.ssh/your-key.pem -r backend/ ubuntu@your-server-ip:/opt/mvp-backend
```

### Exclude Unnecessary Files:

```bash
# Create a temporary directory with only needed files
cd /Users/santosh/coding/mvp
rsync -avz --exclude 'venv' --exclude '.venv' --exclude '__pycache__' \
  --exclude '*.pyc' --exclude '.git' --exclude '.env' \
  backend/ user@your-server-ip:/opt/mvp-backend
```

## Method 3: Using rsync (Best for Updates)

rsync is efficient for syncing files and updating code:

### From Your Local Machine:

```bash
# Initial sync
rsync -avz --exclude 'venv' --exclude '.venv' --exclude '__pycache__' \
  --exclude '*.pyc' --exclude '.git' --exclude '.env' \
  --exclude '*.log' --exclude 'logs/' --exclude 'backups/' \
  backend/ user@your-server-ip:/opt/mvp-backend/

# Example:
rsync -avz --exclude 'venv' --exclude '.venv' --exclude '__pycache__' \
  --exclude '*.pyc' --exclude '.git' --exclude '.env' \
  backend/ ubuntu@192.168.1.100:/opt/mvp-backend/
```

### With SSH Key:

```bash
rsync -avz -e "ssh -i ~/.ssh/your-key.pem" \
  --exclude 'venv' --exclude '.venv' --exclude '__pycache__' \
  --exclude '*.pyc' --exclude '.git' --exclude '.env' \
  backend/ ubuntu@your-server-ip:/opt/mvp-backend/
```

## Method 4: Using tar + SSH (For Large Transfers)

Compress, transfer, and extract:

### From Your Local Machine:

```bash
# Create tar archive (excluding unnecessary files)
cd /Users/santosh/coding/mvp
tar --exclude='venv' --exclude='.venv' --exclude='__pycache__' \
    --exclude='*.pyc' --exclude='.git' --exclude='.env' \
    --exclude='*.log' --exclude='logs' --exclude='backups' \
    -czf backend.tar.gz backend/

# Copy to server
scp backend.tar.gz user@your-server-ip:/tmp/

# SSH into server and extract
ssh user@your-server-ip
sudo mkdir -p /opt
cd /opt
sudo tar -xzf /tmp/backend.tar.gz
sudo mv backend mvp-backend
sudo chown -R $USER:$USER /opt/mvp-backend
rm /tmp/backend.tar.gz
```

## Method 5: Using SFTP (GUI Tools)

If you prefer a GUI:

### Tools:
- **FileZilla** (Cross-platform)
- **WinSCP** (Windows)
- **Cyberduck** (Mac/Windows)
- **VS Code Remote SSH** extension

### Using VS Code Remote SSH:

1. Install "Remote - SSH" extension in VS Code
2. Connect to server: `Ctrl+Shift+P` → "Remote-SSH: Connect to Host"
3. Enter: `user@your-server-ip`
4. Open folder: `/opt/mvp-backend`
5. Copy files directly in VS Code

## Complete Setup Process

After copying code, follow these steps:

### 1. Set Permissions

```bash
# On Ubuntu server
sudo chown -R $USER:$USER /opt/mvp-backend
chmod +x /opt/mvp-backend/deploy/scripts/*.sh
chmod +x /opt/mvp-backend/scripts/*.sh
chmod +x /opt/mvp-backend/deploy/deploy.sh
```

### 2. Initial Server Setup

```bash
cd /opt/mvp-backend
sudo ./deploy/scripts/setup-server.sh
```

### 3. Configure Environment

```bash
cd /opt/mvp-backend
./scripts/generate-env.sh
# Or manually create .env file
```

### 4. Continue with Deployment

Follow the main deployment guide in `deploy/README.md`

## Quick Copy Script

Create a script on your local machine for easy updates:

### `copy-to-server.sh` (on your local machine):

```bash
#!/bin/bash

SERVER="user@your-server-ip"
SERVER_PATH="/opt/mvp-backend"

# Sync code
rsync -avz --exclude 'venv' --exclude '.venv' --exclude '__pycache__' \
  --exclude '*.pyc' --exclude '.git' --exclude '.env' \
  --exclude '*.log' --exclude 'logs/' --exclude 'backups/' \
  --exclude 'celerybeat-schedule' \
  backend/ $SERVER:$SERVER_PATH/

echo "Code copied successfully!"
echo "SSH into server and run: cd $SERVER_PATH && ./deploy/deploy.sh"
```

Make it executable:
```bash
chmod +x copy-to-server.sh
```

Usage:
```bash
./copy-to-server.sh
```

## Troubleshooting

### Permission Denied

```bash
# Fix ownership on server
sudo chown -R $USER:$USER /opt/mvp-backend
```

### Connection Refused

- Check if SSH is running: `sudo systemctl status ssh`
- Check firewall: `sudo ufw status`
- Verify IP address and port

### Large File Transfer Issues

- Use `rsync` with `--progress` to see transfer progress
- Compress first with `tar` for very large directories
- Consider using `screen` or `tmux` for long transfers

### Exclude Files Properly

Make sure to exclude:
- Virtual environments (`venv`, `.venv`)
- Python cache (`__pycache__`, `*.pyc`)
- Git directory (`.git`)
- Environment files (`.env`)
- Logs and backups
- IDE files (`.vscode`, `.idea`)

## Security Notes

1. **Never copy `.env` files** - Create them on the server
2. **Use SSH keys** instead of passwords when possible
3. **Verify file ownership** after copying
4. **Check file permissions** - scripts should be executable

## Next Steps

After copying code:

1. ✅ Verify files are in place: `ls -la /opt/mvp-backend`
2. ✅ Set permissions: `chmod +x deploy/scripts/*.sh`
3. ✅ Run server setup: `sudo ./deploy/scripts/setup-server.sh`
4. ✅ Configure environment: `./scripts/generate-env.sh`
5. ✅ Deploy: `./deploy/deploy.sh`

See `deploy/README.md` for complete deployment instructions.
