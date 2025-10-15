#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up Zsh with Zinit...${NC}"

# Zsh is already installed via Brewfile, just set as default shell
if [[ "$SHELL" != "$(which zsh)" ]]; then
    echo -e "${YELLOW}Setting Zsh as default shell...${NC}"
    chsh -s "$(which zsh)"
    echo -e "${GREEN}Zsh set as default shell${NC}"
else
    echo -e "${GREEN}Zsh already set as default shell${NC}"
fi

mkdir -p ~/.cache

echo -e "${GREEN}Zsh setup complete!${NC}"
echo -e "${YELLOW}Note: Restart your terminal or run 'exec zsh' to load the new configuration${NC}"