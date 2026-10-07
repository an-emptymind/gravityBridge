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
echo -e "${GREEN}  Test Deposit: Ethereum → Cosmos${NC}"
echo -e "${GREEN}========================================${NC}"

# Load configuration
if [ ! -f "$DATA_DIR/contracts.json" ]; then
    echo -e "${RED}Error: Contracts not deployed. Run ./start.sh first${NC}"
    exit 1
fi

GRAVITY_CONTRACT=$(jq -r '.gravity_contract' "$DATA_DIR/contracts.json")
ERC20_CONTRACT=$(jq -r '.erc20_contract' "$DATA_DIR/contracts.json")
DEPLOYER_KEY=$(jq -r '.deployer_key' "$DATA_DIR/contracts.json")

GRAVITY_BIN=$(jq -r '.gravity_binary' "$SCRIPT_DIR/config/local-config.json")
GBT_BIN=$(jq -r '.orchestrator_binary' "$SCRIPT_DIR/config/local-config.json")

# Get destination cosmos address
COSMOS_DEST=$($GRAVITY_BIN keys show validator1 -a --keyring-backend test --home="$DATA_DIR/validator1")

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  Gravity Contract: $GRAVITY_CONTRACT"
echo "  ERC20 Contract:   $ERC20_CONTRACT"
echo "  Cosmos Dest:      $COSMOS_DEST"

# Check initial balance
echo -e "\n${YELLOW}Step 1: Checking initial Cosmos balance...${NC}"
INITIAL_BALANCE=$($GRAVITY_BIN query bank balances $COSMOS_DEST --node http://localhost:26657 -o json 2>/dev/null | jq -r ".balances[] | select(.denom | contains(\"gravity\")) | .amount" || echo "0")
echo "  Initial bridged token balance: $INITIAL_BALANCE"

# Amount to send (1 token with 18 decimals)
AMOUNT="1000000000000000000"  # 1 token
AMOUNT_DISPLAY="1"

echo -e "\n${YELLOW}Step 2: Sending $AMOUNT_DISPLAY ERC20 tokens to Cosmos...${NC}"

# Use gbt client to send tokens
$GBT_BIN client eth-to-cosmos \
    --ethereum-key="$DEPLOYER_KEY" \
    --ethereum-rpc="http://localhost:8545" \
    --gravity-contract-address="$GRAVITY_CONTRACT" \
    --token-contract-address="$ERC20_CONTRACT" \
    --amount="$AMOUNT" \
    --destination="$COSMOS_DEST"

echo -e "  ${GREEN}✓ Transaction submitted${NC}"

# Wait for orchestrators to process
echo -e "\n${YELLOW}Step 3: Waiting for orchestrators to process...${NC}"
echo "  (This may take 30-60 seconds for block confirmations)"

for i in $(seq 1 60); do
    NEW_BALANCE=$($GRAVITY_BIN query bank balances $COSMOS_DEST --node http://localhost:26657 -o json 2>/dev/null | jq -r ".balances[] | select(.denom | contains(\"gravity\")) | .amount" || echo "0")

    if [ "$NEW_BALANCE" != "$INITIAL_BALANCE" ] && [ "$NEW_BALANCE" != "0" ] && [ -n "$NEW_BALANCE" ]; then
        echo -e "\n${GREEN}========================================${NC}"
        echo -e "${GREEN}  Deposit Successful!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "\n  New balance: $NEW_BALANCE"

        # Show the denom
        DENOM=$($GRAVITY_BIN query bank balances $COSMOS_DEST --node http://localhost:26657 -o json 2>/dev/null | jq -r ".balances[] | select(.denom | contains(\"gravity\")) | .denom")
        echo "  Token denom: $DENOM"

        exit 0
    fi

    echo -n "."
    sleep 2
done

echo -e "\n${RED}Timeout waiting for deposit. Check orchestrator logs:${NC}"
echo "  tail -f $DATA_DIR/logs/orchestrator1.log"
exit 1
