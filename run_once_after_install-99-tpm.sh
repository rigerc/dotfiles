#!/bin/bash
set -euo pipefail

source "$HOME/.bashrc"
test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing Tmux Plugin Manager (TPM)...${NC}"

# Set TPM directory
TPM_DIR="$HOME/.tmux/plugins/tpm"

# Create plugins directory if it doesn't exist
PLUGINS_DIR="$HOME/.tmux/plugins"
if [[ ! -d "$PLUGINS_DIR" ]]; then
    echo -e "${YELLOW}Creating tmux plugins directory...${NC}"
    mkdir -p "$PLUGINS_DIR"
fi

# Install TPM if not already installed
if [[ ! -d "$TPM_DIR" ]]; then
    echo -e "${YELLOW}Cloning TPM repository...${NC}"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR" > /dev/null
    echo -e "${GREEN}TPM installed successfully!${NC}"
else
    echo -e "${GREEN}TPM already installed at $TPM_DIR${NC}"
    echo -e "${YELLOW}Updating TPM...${NC}"
    cd "$TPM_DIR"
    git pull origin master
    echo -e "${GREEN}TPM updated successfully!${NC}"
fi

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo -e "${RED}Warning: tmux is not installed. Please install tmux first.${NC}"
    echo -e "${YELLOW}You can install tmux using: brew install tmux${NC}"
    exit 1
fi

tmux source ~/.tmux.conf

echo -e "${GREEN}TPM setup complete!${NC}"