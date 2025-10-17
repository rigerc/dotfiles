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

echo -e "${YELLOW}Rebuilding font cache..${NC}"
fc-cache -f -v 2>/dev/null || true

echo -e "${YELLOW}Generating locales...${NC}"
locale-gen

echo -e "${YELLOW}Installing Tmux plugins...${NC}"
~/.config/tmux/plugins/tpm/bin/install_plugins

echo -e "${RED}Restart shell to finish...${NC}"