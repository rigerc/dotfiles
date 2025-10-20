#!/bin/bash

mkdir -p ".local/share/chezmoi/.tmp"

if command -v bw &> /dev/null; then
    echo "✓ bw command is already installed"
    bw --version
else
    echo "✗ bw command not found"
    echo "Installing bitwarden-cli using pacman..."
    
    # Install using pacman with sudo
    sudo pacman -S --noconfirm --quiet bitwarden-cli
    
    # Verify installation
    if command -v bw &> /dev/null; then
        echo "✓ Successfully installed bw"
        export BW_SESSION=$(bw login --raw)
    else
        echo "✗ Installation failed"
        exit 1
    fi
fi