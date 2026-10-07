#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$SCRIPT_DIR/data"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Test Withdrawal: Cosmos → Ethereum${NC}"
echo -e "${GREEN}========================================${NC}"

# Load configuration
if [ ! -f "$DATA_DIR/contracts.json" ]; then
    echo -e "${RED}Error: Contracts not deployed. Run ./start.sh first${NC}"
    exit 1
fi

GRAVITY_CONTRACT=$(jq -r '.gravity_contract' "$DATA_DIR/contracts.json")
ERC20_CONTRACT=$(jq -r '.erc20_contract' "$DATA_DIR/contracts.json")

GRAVITY_BIN=$(jq -r '.gravity_binary' "$SCRIPT_DIR/config/local-config.json")
GBT_BIN=$(jq -r '.orchestrator_binary' "$SCRIPT_DIR/config/local-config.json")

# Hardhat default account (destination)
ETH_DEST="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

# Get cosmos source (validator1)
COSMOS_SRC=$($GRAVITY_BIN keys show validator1 -a --keyring-backend test --home="$DATA_DIR/validator1")

# Get the bridged token denom
DENOM=$($GRAVITY_BIN query bank balances $COSMOS_SRC --node http://localhost:26657 -o json 2>/dev/null | jq -r ".balances[] | select(.denom | contains(\"gravity\")) | .denom")

if [ -z "$DENOM" ] || [ "$DENOM" = "null" ]; then
    echo -e "${RED}Error: No bridged tokens found in $COSMOS_SRC${NC}"
    echo "Please run ./test-deposit.sh first"
    exit 1
fi

# Get balance
BALANCE=$($GRAVITY_BIN query bank balances $COSMOS_SRC --node http://localhost:26657 -o json 2>/dev/null | jq -r ".balances[] | select(.denom == \"$DENOM\") | .amount")

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  Cosmos Source:    $COSMOS_SRC"
echo "  Ethereum Dest:    $ETH_DEST"
echo "  Token Denom:      $DENOM"
echo "  Available:        $BALANCE"

# Check initial ETH balance
echo -e "\n${YELLOW}Step 1: Checking initial Ethereum balance...${NC}"
INITIAL_ETH_BALANCE=$(curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"$ERC20_CONTRACT\",\"data\":\"0x70a08231000000000000000000000000${ETH_DEST:2}\"}, \"latest\"],\"id\":1}" \
    | jq -r '.result')
echo "  Initial ERC20 balance: $INITIAL_ETH_BALANCE"

# Amount to withdraw (half of available)
WITHDRAW_AMOUNT=$((BALANCE / 2))
if [ "$WITHDRAW_AMOUNT" -lt 1 ]; then
    WITHDRAW_AMOUNT=$BALANCE
fi

# Fee amounts
BRIDGE_FEE=1
CHAIN_FEE=1

echo -e "\n${YELLOW}Step 2: Sending $WITHDRAW_AMOUNT tokens back to Ethereum...${NC}"

# Use gravity tx to send tokens
$GRAVITY_BIN tx gravity send-to-eth \
    $ETH_DEST \
    "${WITHDRAW_AMOUNT}${DENOM}" \
    "${BRIDGE_FEE}${DENOM}" \
    --chain-fee="${CHAIN_FEE}${DENOM}" \
    --from=validator1 \
    --keyring-backend=test \
    --home="$DATA_DIR/validator1" \
    --chain-id="gravity-test-1" \
    --node="http://localhost:26657" \
    --gas=auto \
    --gas-adjustment=1.5 \
    --yes \
    -o json

echo -e "  ${GREEN}✓ Send-to-eth transaction submitted${NC}"

# Wait for batch creation and relay
echo -e "\n${YELLOW}Step 3: Waiting for batch to be created and relayed...${NC}"
echo "  (This may take 60-120 seconds)"

for i in $(seq 1 120); do
    # Check ETH balance
    NEW_ETH_BALANCE=$(curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"$ERC20_CONTRACT\",\"data\":\"0x70a08231000000000000000000000000${ETH_DEST:2}\"}, \"latest\"],\"id\":1}" \
        | jq -r '.result')

    if [ "$NEW_ETH_BALANCE" != "$INITIAL_ETH_BALANCE" ]; then
        echo -e "\n${GREEN}========================================${NC}"
        echo -e "${GREEN}  Withdrawal Successful!${NC}"
        echo -e "${GREEN}========================================${NC}"

        # Convert hex to decimal
        BALANCE_DEC=$(printf "%d" "$NEW_ETH_BALANCE" 2>/dev/null || echo "$NEW_ETH_BALANCE")
        echo -e "\n  New ERC20 balance: $BALANCE_DEC"

        exit 0
    fi

    echo -n "."
    sleep 2
done

echo -e "\n${YELLOW}Batch may still be pending. Check:${NC}"
echo "  - Pending batches: $GRAVITY_BIN query gravity pending-batch-request --node http://localhost:26657"
echo "  - Orchestrator logs: tail -f $DATA_DIR/logs/orchestrator1.log"

# Show pending batches
echo -e "\n${YELLOW}Pending transactions:${NC}"
$GRAVITY_BIN query gravity pending-send-to-eth $COSMOS_SRC --node http://localhost:26657 2>/dev/null || echo "  (none or query failed)"
