#!/data/data/com.termux/files/usr/bin/bash
#!/bin/bash
# =============================================================================
# .chezmoiscripts/.common.sh
# Shared utility functions for all chezmoi scripts
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# Color Definitions
# -----------------------------------------------------------------------------
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

_log() {
    local level="$1" color="$2" emoji="$3" label="$4"; shift 4
    local msg="$*"

    if gum_available; then
        case "$level" in
            step)   gum style --border double  --foreground "$color" "$emoji $msg" >&2 ;;
            header) gum style --border rounded --foreground "$color" "$emoji $msg" >&2 ;;
            *)      gum style --foreground "$color" "$emoji [$label]" "$msg" >&2 ;;
        esac
    else
        case "$level" in
            info)    echo -e "${BLUE}${emoji} [${label}]${NC} $msg" >&2 ;;
            success) echo -e "${GREEN}${emoji} [${label}]${NC} $msg" >&2 ;;
            warning) echo -e "${YELLOW}${emoji} [${label}]${NC} $msg" >&2 ;;
            error)   echo -e "${RED}${emoji} [${label}]${NC} $msg" >&2 ;;
            step)
                echo -e "${YELLOW}┌───────────────────────────────────────────────┐${NC}" >&2
                echo -e "${YELLOW}│ ${emoji}  $msg${NC}" >&2
                echo -e "${YELLOW}└───────────────────────────────────────────────┘${NC}" >&2
                ;;
            header)
                echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}" >&2
                echo -e "${GREEN}║ ${emoji}  $msg${NC}" >&2
                echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}" >&2
                ;;
        esac
    fi
}

# -----------------------------------------------------------------------------
# Public Logging API
# -----------------------------------------------------------------------------
log_info()    { _log info    12 "ℹ️" "INFO"    "$@"; }
log_success() { _log success 10 "✅" "SUCCESS" "$@"; }
log_warning() { _log warning 11 "⚠️" "WARNING" "$@"; }
log_error()   { _log error   9  "❌" "ERROR"   "$@"; }
log_step()    { _log step    11 "🧩" "STEP"    "$@"; }
log_header()  { _log header  10 "🚀" "HEADER"  "$@"; }

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

# Check if gum is available
gum_available() {
    command_exists gum
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

# Check if running on Arch Linux
is_arch() {
    [[ -f /etc/os-release ]] && grep -qi "^ID=arch$" /etc/os-release
}

# Check if running on WSL
is_wsl() {
    [[ -f /proc/version ]] && grep -qi microsoft /proc/version
}

# Check if running on Android
is_android() {
    [[ -d /system/app || -d /system/priv-app ]] || [[ "$(uname -o 2>/dev/null)" == "Android" ]]
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

install_homebrew() {
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

# -----------------------------------------------------------------------------
# NPM Functions
# -----------------------------------------------------------------------------

# Standard NPM installation paths (Node.js)
readonly NODE_PATHS=(
    "$HOME/.nvm/versions/node"
    "$HOME/.volta/tools/image/node"
    "$HOME/.asdf/installs/nodejs"
    "/usr/local/bin"
    "/usr/bin"
)

# Find npm installation
find_npm() {
    # First check if npm is already in PATH
    if command_exists npm; then
        command -v npm
        return 0
    fi

    # Check standard Node.js installation paths
    for path in "${NODE_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            # Find the latest version directory if exists
            local npm_bin
            if [[ -f "$path/bin/npm" ]]; then
                npm_bin="$path/bin/npm"
            elif [[ -d "$path" ]]; then
                # Find latest version in version directories (nvm style)
                local latest_version
                latest_version=$(find "$path" -maxdepth 1 -type d -name "v*" | sort -V | tail -n1)
                if [[ -n "$latest_version" && -f "$latest_version/bin/npm" ]]; then
                    npm_bin="$latest_version/bin/npm"
                fi
            fi

            if [[ -n "$npm_bin" && -x "$npm_bin" ]]; then
                echo "$npm_bin"
                return 0
            fi
        fi
    done
    return 1
}

# Check if npm is available
is_npm_available() {
    command_exists npm
}

# Load npm environment
load_npm() {
    if is_npm_available; then
        return 0
    fi

    local npm_path
    if npm_path=$(find_npm); then
        local npm_dir
        npm_dir=$(dirname "$npm_path")
        export PATH="$npm_dir:$PATH"
        return 0
    fi

    return 1
}

# Install Node.js and npm
install_npm() {
    log_header "Installing Node.js and npm"

    # Check if npm is already available
    if is_npm_available; then
        log_success "npm already installed: $(command -v npm)"
        log_info "Version: $(npm --version)"
        log_info "Node.js: $(node --version)"
        return 0
    fi

    # Try to find existing installation
    if load_npm; then
        log_success "Found existing npm installation"
        log_info "npm version: $(npm --version)"
        log_info "Node.js version: $(node --version)"
        return 0
    fi

    # Determine installation method based on system
    log_info "Installing Node.js and npm..."

    # Try using system package manager first
    if command_exists pacman; then
        log_info "Installing via pacman..."
        sudo pacman -S --noconfirm --needed nodejs npm >/dev/null
    elif command_exists apt-get; then
        log_info "Installing via apt..."
        sudo apt-get update >/dev/null
        sudo apt-get install -y nodejs npm >/dev/null
    elif command_exists yum; then
        log_info "Installing via yum..."
        sudo yum install -y nodejs npm >/dev/null
    elif command_exists brew; then
        log_info "Installing via Homebrew..."
        brew install node >/dev/null
    else
        log_error "No supported package manager found"
        log_info "Please install Node.js manually from https://nodejs.org/"
        return 1
    fi

    # Verify installation
    if ! load_npm; then
        log_error "Cannot find npm after installation"
        return 1
    fi

    log_success "Node.js and npm installation completed"
    log_info "npm location: $(command -v npm)"
    log_info "npm version: $(npm --version)"
    log_info "Node.js version: $(node --version)"
}

# Install package on Arch Linux using pacman
install_pacman_package() {
    local package="$1"

    if ! command_exists pacman; then
        log_error "Not an Arch-based system"
        return 1
    fi

    if pacman -Qi "$package" &>/dev/null; then
        log_success "$package is already installed"
        return 0
    fi

    log_info "Installing $package..."
    if sudo pacman -S --noconfirm --needed "$package" >/dev/null 2>&1; then
        log_success "Installed $package"
        return 0
    else
        log_error "Failed to install $package: $?"
        return 1
    fi
}

# Install package on Termux
install_termux_package() {
    local package="$1"

    if ! command_exists pkg; then
        log_error "Not a Termux system"
        return 1
    fi

    if pkg list-installed 2>/dev/null | grep -q "^$package/"; then
        log_success "$package is already installed"
        return 0
    fi

    log_info "Installing $package..."
    if pkg install -y "$package" >/dev/null 2>&1; then
        log_success "Installed $package"
        return 0
    else
        log_error "Failed to install $package: $?"
        return 1
    fi
}

# Install package using Homebrew
install_homebrew_package() {
    local package="$1"

    if brew list "$package" &>/dev/null; then
        log_success "$package is already installed"
        return 0
    fi

    log_info "Installing $package..."
    if brew install "$package" >/dev/null 2>&1; then
        log_success "Installed $package"
        return 0
    else
        log_error "Failed to install $package: $?"
        return 1
    fi
}

# Install package using Homebrew (Cask)
install_homebrew_cask_package() {
    local package="$1"

    if brew list "$package" &>/dev/null; then
        log_success "$package is already installed"
        return 0
    fi

    log_info "Installing $package..."
    if brew install "$package" >/dev/null 2>&1; then
        log_success "Installed $package"
        return 0
    else
        log_error "Failed to install $package: $?"
        return 1
    fi
}

# Install package using npm
install_npm_package() {
    local package="$1"

    if npm list -g "$package" &>/dev/null; then
        log_success "$package is already installed"
        return 0
    fi

    log_info "Installing $package..."
    if npm install -g "$package" >/dev/null 2>&1; then
        log_success "Installed $package"
        return 0
    else
        log_error "Failed to install $package: $?"
        return 1
    fi
}