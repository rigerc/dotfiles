#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing Iosevka Nerd Font...${NC}"

# Create fonts directory if it doesn't exist
FONTS_DIR="${HOME}/Library/Fonts"
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

# Refresh font cache (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}Refreshing font cache...${NC}"
    # Kill font server to force cache refresh
    killall fontd 2>/dev/null || true
fi

echo -e "${GREEN}Iosevka Nerd Font installed successfully!${NC}"
echo -e "${YELLOW}Update your terminal/editor font to 'Iosevka Nerd Font'${NC}"