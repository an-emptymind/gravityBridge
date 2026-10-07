#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"

echo -e "${YELLOW}Stopping Gravity Bridge...${NC}"

# Function to stop process by PID file
stop_process() {
    local name=$1
    local pid_file=$2

    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            echo -e "  ${GREEN}✓ Stopped $name (PID: $pid)${NC}"
        else
            echo -e "  ${YELLOW}$name not running${NC}"
        fi
        rm -f "$pid_file"
    fi
}

# Stop orchestrators
for i in 1 2 3 4; do
    stop_process "Orchestrator $i" "$DATA_DIR/pids/orchestrator$i.pid"
done

# Stop validators
for i in 1 2 3 4; do
    stop_process "Validator $i" "$DATA_DIR/pids/validator$i.pid"
done

# Stop Hardhat
stop_process "Hardhat" "$DATA_DIR/pids/hardhat.pid"

# Kill any remaining processes
pkill -f "hardhat node" 2>/dev/null || true
pkill -f "gravity start" 2>/dev/null || true
pkill -f "gbt orchestrator" 2>/dev/null || true

echo -e "\n${GREEN}All processes stopped${NC}"
