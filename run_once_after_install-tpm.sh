#!/bin/bash
set -euo pipefail

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

# Source tmux configuration to install plugins
echo -e "${YELLOW}Installing tmux plugins...${NC}"

# Create a temporary tmux session to install plugins
if tmux has-session 2>/dev/null; then
    echo -e "${YELLOW}Tmux session detected. Installing plugins...${NC}"
    # If tmux is running, install plugins in existing session
    tmux new-session -d -s "__tpm_install__" "$TPM_DIR/bin/install_plugins"
    tmux kill-session -t "__tpm_install__"
else
    echo -e "${YELLOW}Creating temporary tmux session to install plugins...${NC}"
    # Create a temporary session just for plugin installation
    tmux new-session -d -s "__tpm_install__" "$TPM_DIR/bin/install_plugins"
    tmux kill-session -t "__tpm_install__"
fi

echo -e "${GREEN}Tmux plugins installed successfully!${NC}"

# Verify plugins are installed
echo -e "${YELLOW}Verifying plugin installation...${NC}"
PLUGINS_INSTALLED=true

# Check for common plugins
COMMON_PLUGINS=(
    "tmux-sensible"
    "tmux-yank"
    "vim-tmux-navigator"
    "tmux-resurrect"
    "tmux-continuum"
)

for plugin in "${COMMON_PLUGINS[@]}"; do
    if [[ -d "$HOME/.tmux/plugins/$plugin" ]]; then
        echo -e "${GREEN}✓ $plugin installed${NC}"
    else
        echo -e "${YELLOW}○ $plugin not found (may not be in your tmux.conf)${NC}"
    fi
done

echo -e "${GREEN}TPM setup complete!${NC}"
echo -e "${YELLOW}To use tmux plugins:${NC}"
echo -e "1. Reload your tmux configuration with: tmux source ~/.tmux.conf"
echo -e "2. Or restart tmux completely"
echo -e "${YELLOW}To manage plugins manually:${NC}"
echo -e "- Install plugins: Prefix + I"
echo -e "- Update plugins: Prefix + U"
echo -e "- Uninstall plugins: Prefix + alt + u"