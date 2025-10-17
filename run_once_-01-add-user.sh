#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function for verbose output
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${YELLOW}Adding user...${NC}"

echo "Creating user $Username..."

useradd -m -G wheel -s /bin/bash $Username || exit 1
echo "${Username}:${Password}" | chpasswd || exit 1

echo "Configuring sudo..."
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

echo "Enabling systemd in WSL..."
cat > /etc/wsl.conf << 'EOF'
[boot]
systemd=true

[user]
default=$Username
EOF