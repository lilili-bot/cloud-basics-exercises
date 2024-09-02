#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Log function for consistent logging
log() {
    echo "[INFO] $1"
}

# Function to display usage
usage() {
    echo "Usage: $0 [public-key-file] [Node.js version (default: 18)]"
    exit 1
}

# Default Node.js version
NODE_VERSION="18"

# Check if public key file is provided
if [ -z "$1" ]; then
    usage
fi

PUBLIC_KEY_FILE="$1"

# Check if a custom Node.js version is provided as an argument
if [ ! -z "$2" ]; then
    NODE_VERSION="$2"
fi

log "Updating package index..."
sudo apt update

log "Installing prerequisite packages (curl, sudo)..."
sudo apt install -y curl sudo

log "Creating new user 'nodeappuser'..."
sudo adduser --disabled-password --gecos "" nodeappuser
sudo usermod -aG sudo nodeappuser

log "Creating application directory /var/www/nodeapp and setting permissions..."
sudo mkdir -p /var/www/nodeapp
sudo chown -R nodeappuser:nodeappuser /var/www/nodeapp

log "Setting up SSH for new user 'nodeappuser'..."

if [ ! -f "$PUBLIC_KEY_FILE" ]; then
    log "Public key file does not exist: $PUBLIC_KEY_FILE"
    exit 1
fi

sudo mkdir -p /home/nodeappuser/.ssh
sudo touch /home/nodeappuser/.ssh/authorized_keys
sudo cat $PUBLIC_KEY_FILE | sudo tee -a /home/nodeappuser/.ssh/authorized_keys > /dev/null
sudo chown -R nodeappuser:nodeappuser /home/nodeappuser/.ssh
sudo chmod 700 /home/nodeappuser/.ssh
sudo chmod 600 /home/nodeappuser/.ssh/authorized_keys

# Switch to the new user and set up the environment
log "Switching to new user 'nodeappuser' to set up Node.js environment..."

sudo su - nodeappuser <<'EOF'
# Log function inside the new user context
log() {
    echo "[INFO] $1"
}

log "Installing NVM (Node Version Manager)..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

log "Installing Node.js version $NODE_VERSION using NVM..."
nvm install $NODE_VERSION

log "Setting Node.js version $NODE_VERSION as default..."
nvm alias default $NODE_VERSION
nvm use default

log "Installing PM2 process manager globally..."
npm install -g pm2

log "Creating a sample Node.js application..."
cd /var/www/nodeapp
echo 'console.log("Hello, World!");' > app.js

log "Starting the application using PM2..."
pm2 start app.js
pm2 save
pm2 startup
EOF

log "Setup completed successfully!"

echo """
To continue managing the Node.js application under the new user:
1. Switch to the nodeappuser: sudo su - nodeappuser
2. Use PM2 to manage the application (pm2 status, pm2 restart, pm2 stop, etc.)

To monitor the application logs:
- Use PM2 log commands such as pm2 logs, pm2 show <app_name_or_id>.
"""
