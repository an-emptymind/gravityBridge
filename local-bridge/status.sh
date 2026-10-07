#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Gravity Bridge Status${NC}"
echo -e "${GREEN}========================================${NC}"

# Check process status
check_process() {
    local name=$1
    local pid_file=$2
    local check_cmd=$3

    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $name (PID: $pid)"
            return 0
        fi
    fi
    echo -e "  ${RED}✗${NC} $name (not running)"
    return 1
}

echo -e "\n${YELLOW}Processes:${NC}"

# Hardhat
check_process "Hardhat (Ethereum)" "$DATA_DIR/pids/hardhat.pid"

# Validators
for i in 1 2 3 4; do
    check_process "Validator $i" "$DATA_DIR/pids/validator$i.pid"
done

# Orchestrators
for i in 1 2 3 4; do
    check_process "Orchestrator $i" "$DATA_DIR/pids/orchestrator$i.pid"
done

# Check endpoints
echo -e "\n${YELLOW}Endpoints:${NC}"

# Ethereum
if curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' > /dev/null 2>&1; then
    BLOCK=$(curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r '.result')
    BLOCK_DEC=$(printf "%d" "$BLOCK" 2>/dev/null || echo "$BLOCK")
    echo -e "  ${GREEN}✓${NC} Ethereum RPC (block: $BLOCK_DEC)"
else
    echo -e "  ${RED}✗${NC} Ethereum RPC"
fi

# Cosmos
if curl -s http://localhost:26657/status > /dev/null 2>&1; then
    BLOCK=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
    echo -e "  ${GREEN}✓${NC} Cosmos RPC (block: $BLOCK)"
else
    echo -e "  ${RED}✗${NC} Cosmos RPC"
fi

# Contracts
echo -e "\n${YELLOW}Contracts:${NC}"
if [ -f "$DATA_DIR/contracts.json" ]; then
    echo "  Gravity:  $(jq -r '.gravity_contract' "$DATA_DIR/contracts.json")"
    echo "  ERC20:    $(jq -r '.erc20_contract' "$DATA_DIR/contracts.json")"
else
    echo -e "  ${RED}Not deployed${NC}"
fi

# Load config
if [ -f "$SCRIPT_DIR/config/local-config.json" ]; then
    GRAVITY_BIN=$(jq -r '.gravity_binary' "$SCRIPT_DIR/config/local-config.json")

    echo -e "\n${YELLOW}Validator Balances:${NC}"
    for i in 1 2 3 4; do
        ADDR=$($GRAVITY_BIN keys show validator$i -a --keyring-backend test --home="$DATA_DIR/validator$i" 2>/dev/null)
        if [ -n "$ADDR" ]; then
            BALANCE=$($GRAVITY_BIN query bank balances $ADDR --node http://localhost:26657 -o json 2>/dev/null | jq -r '.balances | map("\(.amount) \(.denom)") | join(", ")' || echo "error")
            echo "  Validator $i ($ADDR):"
            echo "    $BALANCE"
        fi
    done
fi

echo ""
