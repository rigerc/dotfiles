#!/bin/bash
set -euo pipefail

# Source common functions
source "$(dirname "$0")/.common.sh"

main() {
    log_header "Installing Homebrew"
    
    # Check if already installed
    if is_homebrew_available; then
        log_success "Homebrew already installed: $(command -v brew)"
        log_info "Version: $(brew --version | head -n1)"
        return 0
    fi
    
    # Try to find existing installation
    if load_homebrew; then
        log_success "Found existing Homebrew installation"
        brew --version | head -n1
        return 0
    fi
    
    # Install Homebrew
    log_info "Installing Homebrew..."
    export NONINTERACTIVE=1
    
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        log_success "Homebrew installed"
    else
        log_error "Homebrew installation failed"
        return 1
    fi
    
    # Load newly installed Homebrew
    if ! load_homebrew; then
        log_error "Cannot find Homebrew after installation"
        log_info "Standard locations checked:"
        for path in "${HOMEBREW_PATHS[@]}"; do
            log_info "  - $path"
        done
        return 1
    fi
    
    # Update Homebrew
    log_info "Updating Homebrew..."
    brew update --force --quiet
    
    # Fix zsh permissions if needed
    if command_exists zsh; then
        chmod -R go-w "$(brew --prefix)/share/zsh" 2>/dev/null || true
        log_info "Fixed zsh permissions"
    fi
    
    log_success "Homebrew installation completed"
    log_info "Location: $(command -v brew)"
    log_info "Version: $(brew --version | head -n1)"
}

main "$@"