#!/bin/bash

# Bitwarden Login Automation Script
# This script automates Bitwarden CLI login and stores the session token

set -euo pipefail

# Configuration
BW_EMAIL="${BW_EMAIL:-}"
BW_MASTER_PASSWORD="${BW_MASTER_PASSWORD:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error handling
error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

# Success message
success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Validate and install prerequisites
check_prerequisites() {
    if ! command -v bw &> /dev/null; then
        echo -e "${YELLOW}[INFO] Bitwarden CLI not found. Installing...${NC}"
        if ! sudo pacman -S --noconfirm --quiet bitwarden-cli; then
            error "Failed to install bitwarden-cli"
        fi
        success "Bitwarden CLI installed"
    fi
}

# Get credentials from user or environment
get_credentials() {
    if [ -z "$BW_EMAIL" ]; then
        read -p "Enter Bitwarden email: " BW_EMAIL
    fi
    
    if [ -z "$BW_MASTER_PASSWORD" ]; then
        read -sp "Enter master password: " BW_MASTER_PASSWORD
        echo
    fi
}

# Check if already logged in
is_logged_in() {
    if bw status &> /dev/null; then
        return 0
    fi
    return 1
}

# Perform login
login() {
    echo -e "${YELLOW}[INFO] Attempting to login as: $BW_EMAIL${NC}"
    
    if SESSION_OUTPUT=$(bw login "$BW_EMAIL" "$BW_MASTER_PASSWORD" --raw 2>&1); then
        # Session token is returned on successful login
        BW_SESSION="$SESSION_OUTPUT"
        export BW_SESSION
        success "Successfully logged in to Bitwarden"
        return 0
    else
        error "Failed to login. Check credentials and try again."
    fi
}

# Unlock vault (if already logged in)
unlock_vault() {
    echo -e "${YELLOW}[INFO] Unlocking Bitwarden vault${NC}"
    
    if UNLOCK_OUTPUT=$(bw unlock "$BW_MASTER_PASSWORD" --raw 2>&1); then
        BW_SESSION="$UNLOCK_OUTPUT"
        export BW_SESSION
        success "Vault unlocked successfully"
        return 0
    else
        error "Failed to unlock vault"
    fi
}

# Main execution
main() {
    check_prerequisites
    
    if is_logged_in; then
        echo -e "${YELLOW}[INFO] Already logged in${NC}"
    else
        get_credentials
        login
    fi
    
    # Export session for use in other commands
    export BW_SESSION
    
    # Verify login by syncing
    if bw sync &> /dev/null; then
        success "Vault synced successfully"
    fi
}

# Run main function
main "$@"