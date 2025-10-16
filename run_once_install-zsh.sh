#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up Zsh with Zinit...${NC}"

# Add zsh to /etc/shells if not already present
ZSH_PATH=$(which zsh)
if ! grep -q "^$ZSH_PATH$" /etc/shells; then
    echo -e "${YELLOW}Adding zsh to /etc/shells...${NC}"
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    echo -e "${GREEN}zsh added to /etc/shells${NC}"
else
    echo -e "${GREEN}zsh already in /etc/shells${NC}"
fi

# Zsh is already installed via Brewfile, just set as default shell
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    echo -e "${YELLOW}Setting Zsh as default shell...${NC}"
    chsh -s "$ZSH_PATH"
    echo -e "${GREEN}Zsh set as default shell${NC}"
else
    echo -e "${GREEN}Zsh already set as default shell${NC}"
fi

mkdir -p ~/.cache

echo -e "${GREEN}Zsh setup complete!${NC}"
echo -e "${YELLOW}Starting new Zsh shell...${NC}"
exec zsh