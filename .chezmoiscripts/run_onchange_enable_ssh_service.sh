#!/bin/bash
set -euo pipefail

# Source common functions
source "$(dirname "$0")/common.sh"

# Configuration
readonly SSH_PORT="4444"
readonly SSHD_CONFIG="/etc/ssh/sshd_config"

# Check if systemd is available
has_systemd() {
    command_exists systemctl && [[ -d /run/systemd/system ]]
}

# Backup file with timestamp
backup_file() {
    local file="$1"
    local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "$file" ]]; then
        cp "$file" "$backup"
        log_info "Backup created: $backup"
        echo "$backup"
    fi
}

# Validate SSH configuration
validate_sshd_config() {
    if ! command_exists sshd; then
        log_error "sshd not found"
        return 1
    fi
    
    sudo sshd -t 2>&1
}

# Check if SSH is listening on port
check_ssh_port() {
    local port="$1"
    sleep 2  # Give service time to start
    
    if command_exists ss; then
        ss -tlnp 2>/dev/null | grep -q ":${port}.*LISTEN"
    elif command_exists netstat; then
        netstat -tlnp 2>/dev/null | grep -q ":${port}.*LISTEN"
    else
        log_warning "Cannot verify port (ss/netstat not found)"
        return 0
    fi
}

create_sshd_config() {
    log_info "Creating SSH configuration..."
    
    sudo tee "$SSHD_CONFIG" > /dev/null << 'SSHD_EOF'
# SSH Daemon Configuration
# Port configuration
Port 4444
ListenAddress 0.0.0.0

# Protocol
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

# Public key authentication (disabled)
PubkeyAuthentication no

# Password authentication (enabled)
PasswordAuthentication yes
PermitEmptyPasswords yes

# Challenge response authentication
ChallengeResponseAuthentication no

# Use PAM authentication
UsePAM yes

# Allow all users
AllowUsers *

# Connection settings
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 6
MaxSessions 10

# Security settings
X11Forwarding no
PrintMotd no
TCPKeepAlive yes

# Subsystem configuration
Subsystem sftp /usr/lib/openssh/sftp-server
SSHD_EOF
    
    sudo chmod 644 "$SSHD_CONFIG"
    log_success "SSH configuration created"
}

main() {
    log_header "Configuring SSH Service"
    
    # Check for systemd
    if ! has_systemd; then
        log_error "systemd not available - cannot manage SSH service"
        return 1
    fi
    
    # Backup existing configuration
    if [[ -f "$SSHD_CONFIG" ]]; then
        backup_file "$SSHD_CONFIG"
    fi
    
    # Create SSH configuration
    create_sshd_config
    
    # Generate host keys
    log_info "Generating SSH host keys..."
    if sudo ssh-keygen -A 2>/dev/null; then
        log_success "SSH host keys generated"
    else
        log_warning "SSH host key generation had issues (may already exist)"
    fi
    
    # Validate configuration
    log_info "Validating SSH configuration..."
    if ! validate_sshd_config; then
        log_error "SSH configuration is invalid"
        sudo sshd -t
        return 1
    fi
    log_success "SSH configuration is valid"
    
    # Enable SSH service
    log_info "Enabling SSH service to start on boot..."
    if sudo systemctl enable sshd 2>/dev/null; then
        log_success "SSH service enabled"
    else
        log_warning "Could not enable SSH service"
    fi
    
    # Start SSH service
    log_info "Starting SSH service..."
    if sudo systemctl restart sshd; then
        log_success "SSH service started"
    else
        log_error "Failed to start SSH service"
        sudo systemctl status sshd --no-pager
        return 1
    fi
    
    # Verify service is running
    if ! sudo systemctl is-active --quiet sshd; then
        log_error "SSH service is not running"
        sudo systemctl status sshd --no-pager
        return 1
    fi
    log_success "SSH service is running"
    
    # Check port
    log_info "Verifying SSH is listening on port $SSH_PORT..."
    if check_ssh_port "$SSH_PORT"; then
        log_success "SSH is listening on port $SSH_PORT"
    else
        log_warning "Cannot verify SSH is listening on port $SSH_PORT"
        log_info "Checking all SSH ports..."
        if command_exists ss; then
            sudo ss -tlnp | grep sshd || true
        elif command_exists netstat; then
            sudo netstat -tlnp | grep sshd || true
        fi
    fi
    
    log_header "SSH Service Configuration Completed"
    echo ""
    sudo systemctl status sshd --no-pager --lines=3
}

main "$@"