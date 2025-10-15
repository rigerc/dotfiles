#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing Homebrew and packages from Brewfile...${NC}"

# Install Homebrew if not already installed
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH (for Apple Silicon Macs)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ -d "/opt/homebrew/bin" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    echo -e "${GREEN}Homebrew installed successfully${NC}"
else
    echo -e "${GREEN}Homebrew already installed${NC}"
fi

# Update Homebrew
echo -e "${YELLOW}Updating Homebrew...${NC}"
brew update

# Install from Brewfile if it exists
BREWFILE="{{ .chezmoi.sourceDir }}/Brewfile"
if [[ -f "$BREWFILE" ]]; then
    echo -e "${YELLOW}Installing packages from Brewfile...${NC}"
    brew bundle --file="$BREWFILE"
    echo -e "${GREEN}Brewfile packages installed successfully${NC}"
else
    echo -e "${RED}Brewfile not found at $BREWFILE${NC}"
    echo -e "${YELLOW}Skipping brew bundle installation${NC}"
fi

echo -e "${GREEN}Homebrew setup complete!${NC}"