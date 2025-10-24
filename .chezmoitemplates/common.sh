#!{{ lookPath "bash" }}
# =============================================================================
# utils/common.sh
# Shared utility functions for all chezmoi scripts
# Optimized for faster package installation
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# Color Definitions
# -----------------------------------------------------------------------------
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Debug flag (set to "true" to enable debug logging)
# -----------------------------------------------------------------------------
DEBUG="${DEBUG:-false}"
DEBUG="true"  # Uncomment to enable debug logging

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}ℹ️  [INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}✅ [SUCCESS]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  [WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}❌ [ERROR]${NC} $*" >&2
}

log_debug() {
    if [ "$DEBUG" = "true" ]; then
        # Get timestamp
        local timestamp
        timestamp=$(date '+%H:%M:%S')

        # Get calling function name if available
        local caller=""
        if [ "${#FUNCNAME[@]}" -gt 1 ]; then
            caller="${FUNCNAME[1]}(): "
        fi

        # Get script name for context
        local script_name
        script_name=$(basename "$0")

        # Format debug message with enhanced context
        echo -e "${CYAN}🔍 [DEBUG ${timestamp}]${NC} ${script_name}: ${caller}$*" >&2
    fi
}

log_step() {
    echo -e "${YELLOW}${BOLD}🧩 [STEP] $*${NC}" >&2
}

log_header() {
    echo -e "${GREEN}${BOLD}🚀 [START] $*${NC}" >&2
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
        log_success "Found existing Homebrew installation $(brew --version | head -n1)"
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

# -----------------------------------------------------------------------------
# Optimized Package Installation Functions
# -----------------------------------------------------------------------------

# Batch check installed pacman packages
# Returns a list of packages that are NOT installed
get_missing_pacman_packages() {
    local -n packages=$1
    local missing=()
    
    # Single pacman query for all packages - MUCH faster
    local all_installed
    all_installed=$(pacman -Qq 2>/dev/null)
    
    for pkg in "${packages[@]}"; do
        if ! grep -qx "$pkg" <<<"$all_installed"; then
            missing+=("$pkg")
        fi
    done
    
    printf '%s\n' "${missing[@]}"
}

# Install package on Arch Linux using pacman
install_pacman_package() {
    local package="$1"

    if ! command_exists pacman; then
        log_error "Not an Arch-based system"
        return 1
    fi

    # This function now expects the caller to have already checked if installed
    if sudo pacman -S --noconfirm --needed "$package" >/dev/null 2>&1; then
        log_success "Installed $package"
        return 0
    else
        log_error "Failed to install $package"
        return 1
    fi
}

# Batch check installed Termux packages
get_missing_termux_packages() {
    local -n packages=$1
    local missing=()
    
    # Single dpkg query for all packages - MUCH faster
    local all_installed
    all_installed=$(dpkg -l 2>/dev/null | awk '/^ii/ {print $2}' | cut -d: -f1)
    
    for pkg in "${packages[@]}"; do
        if ! grep -qx "$pkg" <<<"$all_installed"; then
            missing+=("$pkg")
        fi
    done
    
    printf '%s\n' "${missing[@]}"
}

# Install package on Termux
install_termux_package() {
    local package="$1"

    if ! command_exists pkg; then
        log_error "Not a Termux system"
        return 1
    fi

    # This function now expects the caller to have already checked if installed
    if pkg install -y "$package" >/dev/null 2>&1; then
        log_success "Installed $package"
        return 0
    else
        log_error "Failed to install $package"
        return 1
    fi
}

# Batch check installed Homebrew packages
get_missing_homebrew_packages() {
    local -n packages=$1
    local missing=()
    
    # Single brew list command - MUCH faster
    local all_installed
    all_installed=$(brew list --formula -1 2>/dev/null)
    
    for pkg in "${packages[@]}"; do
        if ! grep -qx "$pkg" <<<"$all_installed"; then
            missing+=("$pkg")
        fi
    done
    
    printf '%s\n' "${missing[@]}"
}

# Install package using Homebrew
install_homebrew_package() {
    local package="$1"

    # This function now expects the caller to have already checked if installed
    if brew install "$package" >/dev/null 2>&1; then
        log_success "Installed $package"
        return 0
    else
        log_error "Failed to install $package"
        return 1
    fi
}

# Batch check installed Homebrew casks
get_missing_homebrew_casks() {
    local -n packages=$1
    local missing=()
    
    # Single brew list command for casks
    local all_installed
    all_installed=$(brew list --cask -1 2>/dev/null)
    
    for pkg in "${packages[@]}"; do
        if ! grep -qx "$pkg" <<<"$all_installed"; then
            missing+=("$pkg")
        fi
    done
    
    printf '%s\n' "${missing[@]}"
}

# Install package using Homebrew (Cask)
install_homebrew_cask_package() {
    local package="$1"

    # This function now expects the caller to have already checked if installed
    if brew install --cask "$package" >/dev/null 2>&1; then
        log_success "Installed $package"
        return 0
    else
        log_error "Failed to install $package"
        return 1
    fi
}

# Batch check installed npm packages
get_missing_npm_packages() {
    local -n packages=$1
    local missing=()
    
    # Single npm list command - MUCH faster
    local all_installed
    all_installed=$(npm list -g --depth=0 --parseable 2>/dev/null | xargs -n1 basename)
    
    for pkg in "${packages[@]}"; do
        if ! grep -qx "$pkg" <<<"$all_installed"; then
            missing+=("$pkg")
        fi
    done
    
    printf '%s\n' "${missing[@]}"
}

# Install package using npm
install_npm_package() {
    local package="$1"

    # This function now expects the caller to have already checked if installed
    if npm install -g "$package" >/dev/null 2>&1; then
        log_success "Installed $package"
        return 0
    else
        log_error "Failed to install $package"
        return 1
    fi
}

# Check if running with elevated privileges
is_root() {
    [[ "$EUID" -eq 0 ]] || [[ -n "$SUDO_USER" ]]
}

# Check if sudo is available and we need it
needs_sudo() {
    ! is_root && command_exists sudo
}

# Check if running on Debian/Ubuntu-based system
is_debian() {
    command_exists apt-get
}

# Check if running on RHEL/CentOS/Fedora-based system
is_rhel() {
    command_exists yum || command_exists dnf
}

# Check if running on macOS
is_macos() {
    [[ "$(uname)" == "Darwin" ]]
}

# Install package using system package manager
install_system_package() {
    local package="$1"

    # Fast command check first
    if command -v "$package" >/dev/null 2>&1; then
        log_success "$package is already installed"
        return 0
    fi

    log_info "Installing $package using system package manager..."

    # Try different package managers in order of preference
    if is_arch; then
        install_pacman_package "$package"
    elif is_android; then
        install_termux_package "$package"
    elif is_macos && command_exists brew; then
        install_homebrew_package "$package"
    elif is_debian; then
        # Fast check for Debian systems using dpkg
        if dpkg -s "$package" >/dev/null 2>&1; then
            log_success "$package is already installed"
            return 0
        fi
        
        if needs_sudo; then
            sudo apt-get update >/dev/null 2>&1
            sudo apt-get install -y "$package" >/dev/null 2>&1
        else
            apt-get update >/dev/null 2>&1
            apt-get install -y "$package" >/dev/null 2>&1
        fi
    elif command_exists dnf; then
        # Fast check for dnf systems
        if rpm -q "$package" >/dev/null 2>&1; then
            log_success "$package is already installed"
            return 0
        fi
        
        if needs_sudo; then
            sudo dnf install -y "$package" >/dev/null 2>&1
        else
            dnf install -y "$package" >/dev/null 2>&1
        fi
    elif command_exists yum; then
        # Fast check for yum systems
        if rpm -q "$package" >/dev/null 2>&1; then
            log_success "$package is already installed"
            return 0
        fi
        
        if needs_sudo; then
            sudo yum install -y "$package" >/dev/null 2>&1
        else
            yum install -y "$package" >/dev/null 2>&1
        fi
    elif command_exists brew; then
        brew install "$package" >/dev/null 2>&1
    else
        log_error "No supported package manager found"
        return 1
    fi

    # Check if installation was successful
    if command -v "$package" >/dev/null 2>&1; then
        log_success "$package installed successfully"
        return 0
    else
        log_error "Failed to install $package"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Bitwarden Session Management Functions
# -----------------------------------------------------------------------------
save_bw_session() {
    local session="$1"
    local session_file="$HOME/.bw_session"

    log_debug "Saving Bitwarden session to $session_file..."

    # Validate session parameter
    if [ -z "$session" ]; then
        log_error "Cannot save empty session value"
        return 1
    fi

    # Check if session looks valid (basic format check)
    if [[ ${#session} -lt 10 ]]; then
        log_error "Session value appears too short (${#session} chars), not saving"
        return 1
    fi

    # Create/overwrite the session file
    if echo "$session" > "$session_file"; then
        log_success "Bitwarden session saved to $session_file (${#session} chars)"
        log_debug "Session file permissions: $(ls -la "$session_file" 2>/dev/null || echo 'File not found')"
        return 0
    else
        log_error "Failed to write session to $session_file"
        return 1
    fi
}

delete_bw_session() {
    local session_file="$HOME/.bw_session"

    log_debug "Deleting Bitwarden session file: $session_file"

    if [[ -f "$session_file" ]]; then
        if rm "$session_file"; then
            log_success "Bitwarden session file deleted: $session_file"
            return 0
        else
            log_error "Failed to delete session file: $session_file"
            return 1
        fi
    else
        log_debug "Session file does not exist: $session_file"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# Bitwarden Helper Functions
# -----------------------------------------------------------------------------
bw_check_login_status() {
    log_debug "Checking current login status..."

    local login_check_output
    if login_check_output=$(bw login --check --raw 2>&1); then
        log_debug "Login check successful: ${login_check_output}"
        return 0
    else
        log_debug "Login check failed: ${login_check_output}"
        return 1
    fi
}

bw_perform_login() {
    log_info "Not logged into Bitwarden, attempting login..."

    # Login using API key
    log_debug "Attempting API key login..."
    local login_output
    if ! login_output=$(bw login --apikey --raw); then
        log_error "Bitwarden login failed: ${login_output}"
        return 1
    fi

    log_debug "Login command output: ${login_output}"
    log_success "Bitwarden login successful"
    return 0
}

bw_verify_session() {
    local session="$1"

    log_debug "Verifying login status after login attempt..."
    if ! bw login --check --raw >/dev/null 2>&1; then
        log_error "Login verification failed - not properly authenticated"
        return 1
    fi
    log_debug "Login verification successful"

    log_debug "Verifying session validity..."
    local session_test
    if session_test=$(BW_SESSION="$session" bw status --raw 2>&1); then
        # Parse JSON to check status field
        local status
        status=$(echo "$session_test" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        log_debug "Session test successful: ${session_test}"
        log_debug "Parsed status: ${status}"

        if [ "$status" = "unlocked" ]; then
            log_success "Bitwarden vault unlocked and session verified"
            return 0
        else
            log_error "Session verification failed - status is: ${status} (expected: unlocked)"
            log_error "Exported BW_SESSION may be invalid"
            return 1
        fi
    else
        log_error "Session verification failed: ${session_test}"
        log_error "Exported BW_SESSION may be invalid"
        return 1
    fi
}

bw_unlock_vault() {
    log_debug "Unlocking Bitwarden vault..."
    local session
    session=$(bw unlock --raw)
    local unlock_exit_code=$?

    log_debug "Unlock command exit code: ${unlock_exit_code}"
    log_debug "Unlock command output: ${session}"

    if [ $unlock_exit_code -ne 0 ]; then
        log_error "Failed to unlock Bitwarden vault (exit code: ${unlock_exit_code})"
        log_error "Unlock output: ${session}"
        return 1
    fi

    # Validate session value
    if [ -z "$session" ]; then
        log_error "Session value is empty after unlock"
        return 1
    fi

    # Check if session looks valid (basic format check)
    if [[ ${#session} -lt 10 ]]; then
        log_error "Session value appears too short (${#session} chars): ${session}"
        return 1
    fi

    export BW_SESSION="$session"
    log_debug "BW_SESSION exported successfully (length: ${#BW_SESSION} chars, starts with: ${BW_SESSION:0:8}...)"

    # Return the session for further processing
    echo "$session"
    return 0
}

bw_sync_vault() {
    log_debug "Syncing Bitwarden vault..."
    local sync_output
    if ! sync_output=$(bw sync 2>&1); then
        log_warning "Bitwarden sync failed (continuing anyway): ${sync_output}"
        return 1
    else
        log_debug "Sync output: ${sync_output}"
        log_success "Bitwarden vault synced"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# Bitwarden Login Function
# -----------------------------------------------------------------------------
bw_login() {
    # Set Bitwarden client ID
    export BW_CLIENTID="{{ .bitwarden_clientid | quote }}"

    log_debug "Starting Bitwarden login process..."
    log_debug "Using client ID: ${BW_CLIENTID:0:8}..." # Show only first 8 chars for security

    # Try to source existing session file first
    local session_file="$HOME/.bw_session"
    if [[ -f "$session_file" ]]; then
        log_debug "Found existing session file: $session_file"
        log_debug "Sourcing session file..."

        if source "$session_file"; then
            log_debug "Session file sourced successfully"
            log_debug "BW_SESSION length: ${#BW_SESSION:-0} chars"

            # Verify if the sourced session is valid and vault is unlocked
            if [[ -n "$BW_SESSION" ]] && bw_verify_session "$BW_SESSION"; then
                log_success "Using existing valid session from file"
                # Sync vault and return
                bw_sync_vault
                return 0
            else
                log_debug "Existing session is invalid or expired, proceeding with fresh login"
                # Clear invalid session
                unset BW_SESSION
            fi
        else
            log_warning "Failed to source session file: $session_file"
        fi
    else
        log_debug "No existing session file found: $session_file"
    fi

    # Check if already logged in
    if bw_check_login_status; then
        log_debug "Already logged into Bitwarden"
    else
        # Perform login
        if ! bw_perform_login; then
            return 1
        fi
    fi

    # Unlock vault and get session
    local session
    if ! session=$(bw_unlock_vault); then
        return 1
    fi

    # Verify the session
    if ! bw_verify_session "$session"; then
        return 1
    fi

    # Save the verified session to file
    if save_bw_session "$session"; then
        log_debug "Session saved successfully"
    else
        log_warning "Failed to save session to file, but continuing with in-memory session"
    fi

    # Sync vault
    bw_sync_vault

    # Final verification
    log_debug "Performing final verification..."
    if bw_check_login_status && [[ -n "$BW_SESSION" ]]; then
        log_success "Bitwarden login process completed successfully"
        log_debug "Final status: logged in, session active (${#BW_SESSION} chars)"
        return 0
    else
        log_error "Final verification failed"
        # In debug mode, return 0 instead of 1 on failure
        if [ "$DEBUG" = "true" ]; then
            log_debug "Debug mode: returning 0 instead of 1 on final verification failure"
            return 0
        else
            return 1
        fi
    fi
}