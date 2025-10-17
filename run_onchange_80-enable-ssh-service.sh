#!/bin/bash
# Enable and start SSH service

set -euo pipefail

# Check if running on Arch Linux with systemd
if ! command -v systemctl &> /dev/null; then
    echo "This script requires systemd"
    exit 1
fi

echo "Enabling SSH service to start on boot..."
sudo systemctl enable sshd

echo "Starting SSH service..."
sudo systemctl start sshd

echo "Checking SSH service status..."
sudo systemctl status sshd --no-pager

echo "SSH service is enabled and running on port 4444"