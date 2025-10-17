#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function for verbose output
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

echo -e "${YELLOW}=== Homebrew Installation Script ===${NC}"
log_info "Starting Homebrew installation process"
log_info "Running as user: $(whoami)"
log_info "Operating system: $OSTYPE"
log_info "Current working directory: $(pwd)"

# Install build tools for Linux if needed
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    log_info "Detected Linux system - checking for required build tools"

    if command -v apt-get &> /dev/null; then
        log_info "Detected Debian/Ubuntu system with apt-get"
        log_info "Updating package list (may require sudo password)..."
        sudo apt-get update
        log_info "Installing required packages: build-essential, procps, curl, file, git"
        sudo apt-get install -y build-essential procps curl file git
        log_success "Debian/Ubuntu build tools installed successfully"

    elif command -v dnf &> /dev/null; then
        log_info "Detected Fedora/RHEL/CentOS Stream system with dnf"
        log_info "Installing Development Tools group (may require sudo password)..."
        sudo dnf groupinstall -y "Development Tools"
        log_info "Installing additional packages: procps-ng, curl, file, git"
        sudo dnf install -y procps-ng curl file git
        log_success "Fedora/RHEL build tools installed successfully"

    elif command -v pacman &> /dev/null; then
        log_info "Detected Arch Linux system with pacman"
        log_info "Installing packages: base-devel, procps-ng, curl, file, git, fontconfig"
        sudo pacman -S --needed --noconfirm --quiet base-devel procps-ng curl file git fontconfig
        log_success "Arch Linux build tools installed successfully"

    else
        log_warning "Unsupported Linux package manager. You may need to install build tools manually."
    fi

    log_success "Linux build tools installation completed"
else
    log_info "Skipping Linux build tools installation (not a Linux system)"
fi

# Install Homebrew if not already installed
if ! command -v brew &> /dev/null; then
    log_warning "Homebrew not found in PATH"
    log_info "Starting Homebrew installation process..."
    log_info "Setting NONINTERACTIVE=1 for automated installation"
    export NONINTERACTIVE=1

    log_info "Downloading and running Homebrew installation script from GitHub..."
    log_info "This may take several minutes depending on your network connection"

    # Show progress during download and installation
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        log_error "Homebrew installation failed"
        exit 1
    }

    log_success "Homebrew installation script completed"

    log_info "Configuring Homebrew environment variables and PATH..."

    # Add Homebrew to PATH using brew --prefix (recommended approach)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_info "Detected macOS system - configuring Homebrew for macOS"
        # macOS - try standard locations first, then use brew --prefix if available
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            log_info "Found Homebrew at /opt/homebrew/bin/brew (Apple Silicon)"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            log_info "Found Homebrew at /usr/local/bin/brew (Intel Mac)"
            eval "$(/usr/local/bin/brew shellenv)"
        else
            log_warning "Could not find Homebrew in standard macOS locations"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_info "Detected Linux system - configuring Homebrew for Linux"
        # Linux - try standard locations first, then use brew --prefix if available
        if [[ -d "$HOME/.linuxbrew" ]]; then
            log_info "Found Homebrew at $HOME/.linuxbrew"
            eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
        elif [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
            log_info "Found Homebrew at /home/linuxbrew/.linuxbrew"
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        else
            log_warning "Could not find Homebrew in standard Linux locations"
        fi
    fi

    # Try alternative PATH setup if brew still not found
    if ! command -v brew &> /dev/null; then
        log_warning "Homebrew still not found in PATH, trying alternative locations..."
        # Direct path approach for various installation locations
        log_info "Searching for Homebrew in common installation paths..."
        for BREW_PATH in "/opt/homebrew/bin/brew" "/usr/local/bin/brew" "/home/linuxbrew/.linuxbrew/bin/brew" "$HOME/.linuxbrew/bin/brew"; do
            if [[ -f "$BREW_PATH" ]]; then
                log_info "Found Homebrew at: $BREW_PATH"
                eval "$($BREW_PATH --prefix)/bin/brew shellenv"
                break
            fi
        done
    fi

    # Verify Homebrew installation
    if command -v brew &> /dev/null; then
        log_success "Homebrew is now available in PATH"
        log_info "Homebrew version: $(brew --version | head -n1)"
        log_info "Homebrew prefix: $(brew --prefix)"

        # Add persistent shell configuration
        log_info "Adding Homebrew to shell configuration for persistence..."
        BREW_SHELLENV='eval "$(brew shellenv)"'

        # Add to appropriate shell config file
        if [[ -f "$HOME/.zshrc" ]]; then
            log_info "Found .zshrc file"
            if ! grep -q "brew shellenv" "$HOME/.zshrc"; then
                log_info "Adding Homebrew configuration to .zshrc"
                {
                    echo ""
                    echo "# Homebrew"
                    echo "$BREW_SHELLENV"
                } >> "$HOME/.zshrc"
            else
                log_info "Homebrew configuration already exists in .zshrc"
            fi
        elif [[ -f "$HOME/.bashrc" ]]; then
            log_info "Found .bashrc file"
            if ! grep -q "brew shellenv" "$HOME/.bashrc"; then
                log_info "Adding Homebrew configuration to .bashrc"
                {
                    echo ""
                    echo "# Homebrew"
                    echo "$BREW_SHELLENV"
                } >> "$HOME/.bashrc"
            else
                log_info "Homebrew configuration already exists in .bashrc"
            fi
        else
            log_warning "No shell configuration file found (.zshrc or .bashrc)"
        fi

        log_success "Homebrew installation and configuration completed successfully!"
    else
        log_error "Failed to locate Homebrew after installation"
        log_error "Please check the installation logs and try again"
        exit 1
    fi
else
    log_success "Homebrew is already installed"
    log_info "Homebrew version: $(brew --version | head -n1)"
    log_info "Homebrew prefix: $(brew --prefix)"
fi

# Update Homebrew
log_info "Skipping automatic Homebrew update (commented out)"
#log_info "Updating Homebrew..."
#brew update || log_warning "Homebrew update failed, continuing..."

# Install Brews (commented out - handled by separate script)
log_info "Package installation is handled by run_onchange_99-install-homebrew-packages.sh"
log_info "This script only sets up the Homebrew installation"

log_info "Shell configuration will be applied on next login or by running: source ~/.zshrc (or ~/.bashrc)"

echo -e "${GREEN}=== Homebrew Setup Complete ===${NC}"
log_success "Homebrew installation and configuration process finished successfully!"
log_info "You can now use 'brew' to install packages"
log_info "Run 'chezmoi apply' to install the configured packages"