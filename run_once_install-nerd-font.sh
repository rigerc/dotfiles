#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing Iosevka Nerd Font...${NC}"

# Check if unzip is available, install if needed
if ! command -v unzip &> /dev/null; then
    echo -e "${YELLOW}unzip not found. Installing unzip...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install unzip
        else
            echo -e "${RED}Homebrew not found. Please install unzip manually.${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            echo "Installing unzip (may require password)..."
            sudo apt-get update && sudo apt-get install -y unzip
        elif command -v dnf &> /dev/null; then
            # Fedora/RHEL/CentOS
            echo "Installing unzip (may require password)..."
            sudo dnf install -y unzip
        elif command -v pacman &> /dev/null; then
            # Arch Linux
            echo "Installing unzip (may require password)..."
            sudo pacman -S --noconfirm unzip
        else
            echo -e "${RED}Unsupported package manager. Please install unzip manually.${NC}"
            exit 1
        fi
    fi
fi

# Create fonts directory if it doesn't exist
if [[ "$OSTYPE" == "darwin"* ]]; then
    FONTS_DIR="${HOME}/Library/Fonts"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    FONTS_DIR="${HOME}/.local/share/fonts"
    mkdir -p "$HOME/.local/share"
fi

if [[ ! -d "$FONTS_DIR" ]]; then
    mkdir -p "$FONTS_DIR"
fi

# Download and install Iosevka Nerd Font
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Iosevka.zip"
TEMP_DIR=$(mktemp -d)

echo -e "${YELLOW}Downloading Iosevka Nerd Font...${NC}"
curl -fsSL "$FONT_URL" -o "$TEMP_DIR/Iosevka.zip"

echo -e "${YELLOW}Extracting fonts...${NC}"
unzip -q "$TEMP_DIR/Iosevka.zip" -d "$TEMP_DIR"

echo -e "${YELLOW}Installing fonts to ~/Library/Fonts...${NC}"
cp "$TEMP_DIR"/*.ttf "$FONTS_DIR/" 2>/dev/null || true

# Cleanup
rm -rf "$TEMP_DIR"

# Refresh font cache
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}Refreshing font cache...${NC}"
    # Kill font server to force cache refresh
    killall fontd 2>/dev/null || true
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${YELLOW}Refreshing font cache...${NC}"
    # Update font cache on Linux
    fc-cache -f -v 2>/dev/null || true
fi

echo -e "${GREEN}Iosevka Nerd Font installed successfully!${NC}"
echo -e "${YELLOW}Update your terminal/editor font to 'Iosevka Nerd Font'${NC}"