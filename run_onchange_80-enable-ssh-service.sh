#!/bin/bash
# Configure and enable SSH service with custom settings

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on systemd-based system
if ! command -v systemctl &> /dev/null; then
    log_error "This script requires systemd"
    exit 1
fi

log_info "Configuring SSH service for port 4444 with passwordless authentication..."

# SSH configuration file path
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_CONFIG_BACKUP="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"

# Backup existing configuration
if [[ -f "$SSHD_CONFIG" ]]; then
    log_info "Creating backup of existing sshd_config..."
    sudo cp "$SSHD_CONFIG" "$SSHD_CONFIG_BACKUP"
    log_success "Backup created at $SSHD_CONFIG_BACKUP"
fi

# Create new sshd configuration
log_info "Creating new SSH configuration..."

sudo tee "$SSHD_CONFIG" > /dev/null << 'EOF'
# SSH Daemon Configuration
# Port configuration
Port 4444

# Listen Address
ListenAddress 0.0.0.0

# Protocol version
Protocol 2

# Host keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Logging
SyslogFacility AUTH
LogLevel INFO

# Authentication settings
LoginGraceTime 120
PermitRootLogin yes
StrictModes yes

# Public key authentication (disabled for password-only)
PubkeyAuthentication no
# AuthorizedKeysFile .ssh/authorized_keys

# Password authentication (enabled)
PasswordAuthentication yes
PermitEmptyPasswords yes

# Challenge response authentication
ChallengeResponseAuthentication no

# Use PAM authentication
UsePAM yes

# Allow all users
AllowUsers *

# Subsystem configuration
Subsystem sftp /usr/lib/openssh/sftp-server

# Connection settings
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 6
MaxSessions 10

# Security settings
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes

# Banner (optional)
# Banner /etc/issue.net
EOF

log_success "SSH configuration updated"

if sudo ssh-keygen -A; then
    log_success "SSH host keys generated"
else
    log_error "SSH host key generation failed"
    exit 1
fi

# Set proper permissions for sshd_config
sudo chmod 644 "$SSHD_CONFIG"
log_info "Set proper permissions for sshd_config"

# Validate SSH configuration
log_info "Validating SSH configuration..."
if sudo sshd -t; then
    log_success "SSH configuration is valid"
else
    log_error "SSH configuration validation failed"
    log_info "Restoring backup configuration..."
    sudo mv "$SSHD_CONFIG_BACKUP" "$SSHD_CONFIG"
    exit 1
fi

# Enable SSH service to start on boot
log_info "Enabling SSH service to start on boot..."
sudo systemctl enable sshd

# Start SSH service
log_info "Starting SSH service..."
sudo systemctl restart sshd

# Check SSH service status
log_info "Checking SSH service status..."
if sudo systemctl is-active --quiet sshd; then
    log_success "SSH service is running"
else
    log_error "SSH service failed to start"
    sudo systemctl status sshd --no-pager
    exit 1
fi

# Check if SSH is listening on port 4444
log_info "Checking if SSH is listening on port 4444..."
sleep 2  # Give service time to start
if sudo netstat -tlnp | grep -q ":4444.*LISTEN"; then
    log_success "SSH is listening on port 4444"
else
    log_warning "SSH may not be listening on port 4444"
    log_info "Checking all listening ports..."
    sudo netstat -tlnp | grep sshd
fi

# Display configuration summary
log_success "SSH service configuration completed!"
echo "SSH service status:"
sudo systemctl status sshd --no-pager --lines=3