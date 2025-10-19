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
echo -e "${YELLOW}Homebrew initialization...${NC}"
exec /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"



# Check if Homebrew is already installed
if command -v brew >/dev/null 2>&1; then
    log_success "Homebrew is already installed at: $(which brew)"
    log_info "Homebrew version: $(brew --version | head -n1)"
else
    # Try to find Homebrew in standard locations
    if [[ -d /home/linuxbrew/.linuxbrew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        log_success "Found and loaded Homebrew from /home/linuxbrew/.linuxbrew"
    elif [[ -d ~/.linuxbrew ]]; then
        eval "$(~/.linuxbrew/bin/brew shellenv)"
        log_success "Found and loaded Homebrew from ~/.linuxbrew"
    else
        log_error "Homebrew not found in standard locations"
        log_info "Please ensure Homebrew is installed first"
        exit 1
    fi
fi

# Update Homebrew
log_info "Updating Homebrew..."
brew update --force --quiet

# Fix zsh permissions if needed
if command -v zsh >/dev/null 2>&1; then
    chmod -R go-w "$(brew --prefix)/share/zsh"
    log_info "Fixed zsh permissions"
fi

log_success "Homebrew initialization completed"