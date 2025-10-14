#!/bin/bash
# run_once_install-lazyvim.sh
# Install LazyVim configuration

set -e

echo "→ Setting up LazyVim..."

# Backup existing nvim config
if [ -d "${HOME}/.config/nvim" ]; then
    echo "  Backing up existing nvim config..."
    mv ~/.config/nvim ~/.config/nvim.bak.$(date +%Y%m%d%H%M%S)
fi

if [ -d "${HOME}/.local/share/nvim" ]; then
    echo "  Backing up existing nvim data..."
    mv ~/.local/share/nvim ~/.local/share/nvim.bak.$(date +%Y%m%d%H%M%S)
fi

if [ -d "${HOME}/.local/state/nvim" ]; then
    echo "  Backing up existing nvim state..."
    mv ~/.local/state/nvim ~/.local/state/nvim.bak.$(date +%Y%m%d%H%M%S)
fi

if [ -d "${HOME}/.cache/nvim" ]; then
    echo "  Backing up existing nvim cache..."
    mv ~/.cache/nvim ~/.cache/nvim.bak.$(date +%Y%m%d%H%M%S)
fi

# Clone LazyVim starter
echo "  Cloning LazyVim starter..."
git clone https://github.com/LazyVim/starter ~/.config/nvim

# Remove .git directory to make it your own
rm -rf ~/.config/nvim/.git

echo "✅ LazyVim installed! Run 'nvim' to complete setup."