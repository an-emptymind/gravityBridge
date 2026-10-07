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
LOGS_DIR="$DATA_DIR/logs"

# Load config
if [ ! -f "$SCRIPT_DIR/config/local-config.json" ]; then
    echo -e "${RED}Error: Configuration not found. Run ./setup.sh first${NC}"
    exit 1
fi

GRAVITY_BIN=$(jq -r '.gravity_binary' "$SCRIPT_DIR/config/local-config.json")
GBT_BIN=$(jq -r '.orchestrator_binary' "$SCRIPT_DIR/config/local-config.json")
NUM_VALIDATORS=$(jq -r '.num_validators' "$SCRIPT_DIR/config/local-config.json")

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Starting Gravity Bridge${NC}"
echo -e "${GREEN}========================================${NC}"

# Create PID file directory
mkdir -p "$DATA_DIR/pids"

# Function to check if a process is running
is_running() {
    local pid_file="$1"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Step 1: Start Hardhat (Ethereum)
echo -e "\n${YELLOW}Step 1: Starting Ethereum (Hardhat)...${NC}"

if is_running "$DATA_DIR/pids/hardhat.pid"; then
    echo -e "  ${BLUE}Hardhat already running${NC}"
else
    cd "$ROOT_DIR/solidity"

    # Start Hardhat in background
    npx hardhat node > "$LOGS_DIR/hardhat.log" 2>&1 &
    HARDHAT_PID=$!
    echo $HARDHAT_PID > "$DATA_DIR/pids/hardhat.pid"

    # Wait for Hardhat to start
    echo -n "  Waiting for Hardhat"
    for i in $(seq 1 30); do
        if curl -s http://localhost:8545 -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' > /dev/null 2>&1; then
            echo -e "\n  ${GREEN}✓ Hardhat started (PID: $HARDHAT_PID)${NC}"
            break
        fi
        echo -n "."
        sleep 1
    done
fi

# Step 2: Start Cosmos validators
echo -e "\n${YELLOW}Step 2: Starting Cosmos validators...${NC}"

for i in $(seq 1 $NUM_VALIDATORS); do
    VALIDATOR_HOME="$DATA_DIR/validator$i"
    PID_FILE="$DATA_DIR/pids/validator$i.pid"

    if is_running "$PID_FILE"; then
        echo -e "  ${BLUE}Validator $i already running${NC}"
        continue
    fi

    # Calculate ports
    RPC_PORT=$((26657 + (i-1)*100))
    GRPC_PORT=$((9090 + (i-1)*10))

    $GRAVITY_BIN start \
        --home="$VALIDATOR_HOME" \
        --rpc.laddr="tcp://0.0.0.0:$RPC_PORT" \
        --grpc.address="0.0.0.0:$GRPC_PORT" \
        --minimum-gas-prices="0ugraviton" \
        --log_level="info" \
        > "$LOGS_DIR/validator$i.log" 2>&1 &

    echo $! > "$PID_FILE"
    echo -e "  ${GREEN}✓ Validator $i started (RPC: $RPC_PORT, gRPC: $GRPC_PORT)${NC}"
done

# Wait for Cosmos chain to be ready
echo -n "  Waiting for Cosmos chain"
for i in $(seq 1 60); do
    if curl -s http://localhost:26657/status > /dev/null 2>&1; then
        BLOCK=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
        if [ "$BLOCK" != "0" ] && [ "$BLOCK" != "null" ]; then
            echo -e "\n  ${GREEN}✓ Cosmos chain ready (block: $BLOCK)${NC}"
            break
        fi
    fi
    echo -n "."
    sleep 1
done

# Step 3: Deploy Contracts
echo -e "\n${YELLOW}Step 3: Deploying Gravity contracts...${NC}"

if [ -f "$DATA_DIR/contracts.json" ]; then
    echo -e "  ${BLUE}Contracts already deployed${NC}"
    GRAVITY_CONTRACT=$(jq -r '.gravity_contract' "$DATA_DIR/contracts.json")
    ERC20_CONTRACT=$(jq -r '.erc20_contract' "$DATA_DIR/contracts.json")
else
    cd "$ROOT_DIR/solidity"

    # Use Hardhat's first account (has 10000 ETH)
    DEPLOYER_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

    # Deploy using contract-deployer.ts
    echo "  Deploying contracts..."

    OUTPUT=$(npx ts-node contract-deployer.ts \
        --cosmos-node="http://localhost" \
        --eth-node="http://localhost:8545" \
        --eth-privkey="$DEPLOYER_KEY" \
        --contract="artifacts/contracts/Gravity.sol/Gravity.json" \
        --contractERC721="artifacts/contracts/GravityERC721.sol/GravityERC721.json" \
        --contractERC20A="artifacts/contracts/TestERC20A.sol/TestERC20A.json" \
        --contractERC20B="artifacts/contracts/TestERC20B.sol/TestERC20B.json" \
        --contractERC20C="artifacts/contracts/TestERC20C.sol/TestERC20C.json" \
        --test-mode=true 2>&1)

    echo "$OUTPUT" > "$LOGS_DIR/deploy.log"

    # Parse contract addresses
    GRAVITY_CONTRACT=$(echo "$OUTPUT" | grep "Gravity deployed at Address" | awk '{print $NF}')
    GRAVITY_ERC721=$(echo "$OUTPUT" | grep "GravityERC721 deployed at Address" | awk '{print $NF}')
    ERC20_CONTRACT=$(echo "$OUTPUT" | grep "ERC20 deployed at Address" | head -1 | awk '{print $NF}')

    if [ -z "$GRAVITY_CONTRACT" ]; then
        echo -e "  ${RED}Failed to deploy contracts. Check $LOGS_DIR/deploy.log${NC}"
        exit 1
    fi

    # Save contract addresses
    cat > "$DATA_DIR/contracts.json" << EOF
{
    "gravity_contract": "$GRAVITY_CONTRACT",
    "gravity_erc721_contract": "$GRAVITY_ERC721",
    "erc20_contract": "$ERC20_CONTRACT",
    "deployer_key": "$DEPLOYER_KEY"
}
EOF

    echo -e "  ${GREEN}✓ Gravity Contract: $GRAVITY_CONTRACT${NC}"
    echo -e "  ${GREEN}✓ ERC20 Contract: $ERC20_CONTRACT${NC}"
fi

# Step 4: Start Orchestrators
echo -e "\n${YELLOW}Step 4: Starting Orchestrators...${NC}"

GRAVITY_CONTRACT=$(jq -r '.gravity_contract' "$DATA_DIR/contracts.json")

# Pre-defined Ethereum private keys (same as in setup.sh)
ETH_KEYS=(
    "0xc5e8f61d1ab959b397eecc0a37a6517b8e67a0e7cf1f4bce5591f3ed80199122"
    "0xd49743deccbccc5dc7baa8e69e5be03298da8688a15dd202e20f15d5e0e9a9fb"
    "0x23c601ae397441f3ef6f1075dcb0031ff17fb079837beadaf3c84d96c6f3e569"
    "0xee9d129c1997549ee09c0757af5939b2483d80ad649a0eda68e8b0357ad11131"
)

for i in $(seq 1 $NUM_VALIDATORS); do
    PID_FILE="$DATA_DIR/pids/orchestrator$i.pid"

    if is_running "$PID_FILE"; then
        echo -e "  ${BLUE}Orchestrator $i already running${NC}"
        continue
    fi

    VALIDATOR_HOME="$DATA_DIR/validator$i"

    # Get orchestrator phrase (line i from the file)
    ORCH_PHRASE=$(sed -n "${i}p" "$DATA_DIR/orchestrator-phrases.txt")

    # Get ethereum private key from predefined array
    ETH_KEY="${ETH_KEYS[$((i-1))]}"

    # Start orchestrator
    $GBT_BIN orchestrator \
        --cosmos-grpc="http://localhost:9090" \
        --ethereum-rpc="http://localhost:8545" \
        --ethereum-key="$ETH_KEY" \
        --cosmos-phrase="$ORCH_PHRASE" \
        --fees="0ugraviton" \
        --gravity-contract-address="$GRAVITY_CONTRACT" \
        > "$LOGS_DIR/orchestrator$i.log" 2>&1 &

    echo $! > "$PID_FILE"
    echo -e "  ${GREEN}✓ Orchestrator $i started${NC}"
done

# Wait for orchestrators to sync
echo -n "  Waiting for orchestrators to sync"
sleep 10
echo -e "\n  ${GREEN}✓ Orchestrators synced${NC}"

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Gravity Bridge Started!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Endpoints:${NC}"
echo "  Cosmos RPC:  http://localhost:26657"
echo "  Cosmos gRPC: http://localhost:9090"
echo "  Cosmos API:  http://localhost:1317"
echo "  Ethereum:    http://localhost:8545"

echo -e "\n${YELLOW}Contracts:${NC}"
echo "  Gravity:     $(jq -r '.gravity_contract' "$DATA_DIR/contracts.json")"
echo "  ERC20:       $(jq -r '.erc20_contract' "$DATA_DIR/contracts.json")"

echo -e "\n${YELLOW}Logs:${NC}"
echo "  Hardhat:       $LOGS_DIR/hardhat.log"
echo "  Validators:    $LOGS_DIR/validator*.log"
echo "  Orchestrators: $LOGS_DIR/orchestrator*.log"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "  - Test deposit:    ./test-deposit.sh"
echo "  - Test withdrawal: ./test-withdraw.sh"
echo "  - Stop all:        ./stop.sh"
