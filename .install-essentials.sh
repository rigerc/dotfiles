#!/bin/bash

# Check if bitwarden-cli is installed
if ! command -v bw &> /dev/null; then
    echo "Bitwarden CLI not found. Installing..."
    sudo pacman -S --noconfirm --quiet bitwarden-cli
fi

# Login to Bitwarden and export session
echo "Logging in to Bitwarden..."
export BW_SESSION=$(bw login --raw)

if [ $? -eq 0 ]; then
    echo "Successfully logged in to Bitwarden"
    echo "Session exported to BW_SESSION variable"
else
    echo "Failed to login to Bitwarden"
    exit 1
fi