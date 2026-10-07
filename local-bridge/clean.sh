#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"

echo -e "${YELLOW}Cleaning up Gravity Bridge data...${NC}"

# Stop all processes first
./stop.sh 2>/dev/null || true

# Remove data directory
rm -rf "$DATA_DIR"

# Remove config
rm -rf "$SCRIPT_DIR/config"

echo -e "${GREEN}Clean complete. Run ./setup.sh to reinitialize.${NC}"
