#!/bin/bash
set -euo pipefail

mkdir -p ".local/share/chezmoi/.tmp"

if command -v bw &> /dev/null; then
    echo -e "✓ bw command is already installed"
    bw --version
else
    echo -e "✗ bw command not found"
    echo -e "Installing bitwarden-cli using pacman..."
    
    # Install using pacman with sudo
    sudo pacman -S --noconfirm --quiet bitwarden-cli
    
    # Verify installation
    if command -v bw &> /dev/null; then
        echo -e "✓ Successfully installed bw"
    else
        echo -e "✗ Installation failed"
        exit 1
    fi
fi

export BW_SESSION=$(bw login --raw)