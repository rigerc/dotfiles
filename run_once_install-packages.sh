#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing packages from chezmoi declarative configuration...${NC}"

# Install build tools for Linux if needed
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${YELLOW}Checking for Linux build tools...${NC}"
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        echo "Running sudo apt-get update (may require password)..."
        sudo apt-get update
        echo "Installing build tools (may require password)..."
        sudo apt-get install -y build-essential procps curl file git
    elif command -v dnf &> /dev/null; then
        # Fedora/RHEL/CentOS Stream
        echo "Installing build tools (may require password)..."
        sudo dnf groupinstall -y "Development Tools"
        sudo dnf install -y procps-ng curl file git
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        echo "Installing build tools (may require password)..."
        sudo pacman -S --needed --noconfirm base-devel procps-ng curl file git
    fi
    echo -e "${GREEN}Build tools installed/verified${NC}"
fi

# Install Homebrew if not already installed
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH using brew --prefix (recommended approach)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - try standard locations first, then use brew --prefix if available
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux - try standard locations first, then use brew --prefix if available
        if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        elif [[ -f "$HOME/.linuxbrew/bin/brew" ]]; then
            eval "$("$HOME/.linuxbrew/bin/brew shellenv")"
        fi
    fi

    # Try alternative PATH setup if brew still not found
    if ! command -v brew &> /dev/null; then
        # Direct path approach for various installation locations
        for BREW_PATH in "/opt/homebrew/bin/brew" "/usr/local/bin/brew" "/home/linuxbrew/.linuxbrew/bin/brew" "$HOME/.linuxbrew/bin/brew"; do
            if [[ -f "$BREW_PATH" ]]; then
                eval "$($BREW_PATH --prefix)/bin/brew shellenv"
                break
            fi
        done
    fi

    # Add persistent shell configuration
    if command -v brew &> /dev/null; then
        BREW_SHELLENV='eval "$(brew shellenv)"'

        # Add to appropriate shell config file
        if [[ -f "$HOME/.zshrc" ]]; then
            if ! grep -q "brew shellenv" "$HOME/.zshrc"; then
                echo "" >> "$HOME/.zshrc"
                echo "# Homebrew" >> "$HOME/.zshrc"
                echo "$BREW_SHELLENV" >> "$HOME/.zshrc"
            fi
        elif [[ -f "$HOME/.bashrc" ]]; then
            if ! grep -q "brew shellenv" "$HOME/.bashrc"; then
                echo "" >> "$HOME/.bashrc"
                echo "# Homebrew" >> "$HOME/.bashrc"
                echo "$BREW_SHELLENV" >> "$HOME/.bashrc"
            fi
        fi
    fi
    echo -e "${GREEN}Homebrew installed successfully${NC}"
else
    echo -e "${GREEN}Homebrew already installed${NC}"
fi

# Update Homebrew
echo -e "${YELLOW}Updating Homebrew...${NC}"
brew update

# Install taps first
echo -e "${YELLOW}Installing Homebrew taps...${NC}"
for tap in homebrew/bundle homebrew/services; do
    if ! brew tap | grep -q "$tap"; then
        echo "Installing tap: $tap"
        brew tap "$tap"
    else
        echo "Tap $tap already installed"
    fi
done

# Function to install a package if not already installed
install_brew_package() {
    local package=$1
    if brew list "$package" &>/dev/null; then
        echo "✓ $package already installed"
        return 0
    else
        echo "Installing $package..."
        if brew install "$package"; then
            echo "✓ $package installed successfully"
            return 0
        else
            echo "✗ Failed to install $package"
            return 1
        fi
    fi
}

# Install packages from chezmoi data
echo -e "${YELLOW}Installing packages from chezmoi configuration...${NC}"

# Define packages array
packages=(
    # Development
    "node" "python" "ruby" "golang" "rust"
    # Build tools
    "cmake" "make"
    # Version control & tools
    "gh" "git-lfs" "lazygit" "tmux"
    # Text editors
    "nano" "neovim"
    # Utilities
    "jq" "yq" "ripgrep" "fd" "fzf" "bat" "htop" "tldr" "eza" "zoxide" "fastfetch"
    # Shell
    "zsh"
)

# Install packages
failed_packages=()
for package in "${packages[@]}"; do
    if ! install_brew_package "$package"; then
        failed_packages+=("$package")
    fi
done

# Report failed installations
if [[ ${#failed_packages[@]} -gt 0 ]]; then
    echo -e "${RED}Some packages failed to install: ${failed_packages[*]}${NC}"
    echo -e "${YELLOW}You can try installing them manually with: brew install <package>${NC}"
else
    echo -e "${GREEN}All packages installed successfully!${NC}"
fi

echo -e "${GREEN}Package installation complete!${NC}"