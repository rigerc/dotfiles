#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing uv...${NC}"

# Install uv if not already installed
if ! command -v uv &> /dev/null; then
    echo -e "${YELLOW}uv not found. Installing uv...${NC}"
    /bin/bash -c "$(curl -LsSf https://astral.sh/uv/install.sh | sh)" > /dev/null
    echo -e "${GREEN}uv installed successfully${NC}"
else
    echo -e "${GREEN}uv already installed${NC}"
fi

echo -e "${GREEN}uv setup complete!${NC}"