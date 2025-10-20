#!/bin/bash
# =============================================================================
# .chezmoiscripts/common.sh
# Shared utility functions for all chezmoi scripts
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Color Definitions
# -----------------------------------------------------------------------------
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_step() {
    echo -e "${YELLOW}───────────────────────────────────────────────────${NC}" >&2
    echo -e "${YELLOW}$*${NC}" >&2
}

log_header() {
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}" >&2
    echo -e "${GREEN}$*${NC}" >&2
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}" >&2
}

# -----------------------------------------------------------------------------
# Error Handling
# -----------------------------------------------------------------------------
error_handler() {
    local line_num=$1
    log_error "Script failed at line ${line_num}"
    exit 1
}

trap 'error_handler ${LINENO}' ERR

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Create directory if it doesn't exist
ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

# Safe file copy with directory creation
safe_copy() {
    local source="$1"
    local target="$2"
    
    if [[ ! -e "$source" ]]; then
        log_warning "Source not found: $source"
        return 1
    fi
    
    local target_dir
    target_dir=$(dirname "$target")
    ensure_directory "$target_dir"
    
    if [[ -d "$source" ]]; then
        # Directory copy
        [[ -d "$target" ]] && rm -rf "$target"
        cp -r "$source" "$target"
    else
        # File copy
        cp "$source" "$target"
    fi
    
    if [[ -e "$target" ]]; then
        log_success "Copied to $target"
        return 0
    else
        log_error "Copy failed: $target not found after copy"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Homebrew Functions
# -----------------------------------------------------------------------------

# Standard Homebrew installation paths
readonly HOMEBREW_PATHS=(
    "$HOME/.linuxbrew"
    "/home/linuxbrew/.linuxbrew"
    "/opt/homebrew"  # Apple Silicon
    "/usr/local"     # Intel Mac
)

# Find Homebrew installation
find_homebrew() {
    for path in "${HOMEBREW_PATHS[@]}"; do
        if [[ -d "$path" && -x "$path/bin/brew" ]]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

# Check if Homebrew is in PATH
is_homebrew_available() {
    command_exists brew
}

# Load Homebrew environment
load_homebrew() {
    if is_homebrew_available; then
        return 0
    fi
    
    local homebrew_path
    if homebrew_path=$(find_homebrew); then
        eval "$($homebrew_path/bin/brew shellenv)"
        return 0
    fi
    
    return 1
}

# =============================================================================
# END OF COMMON.SH
# =============================================================================