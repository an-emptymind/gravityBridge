#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Gravity Bridge Local Setup${NC}"
echo -e "${GREEN}========================================${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Create data directories
mkdir -p "$SCRIPT_DIR/data"
mkdir -p "$SCRIPT_DIR/data/logs"
mkdir -p "$SCRIPT_DIR/config"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        echo "Please install it: $2"
        exit 1
    fi
    echo -e "  ✓ $1 found"
}

check_command "go" "brew install go"
check_command "cargo" "brew install rust"
check_command "node" "brew install node"
check_command "jq" "brew install jq"

# Pre-defined Ethereum private keys from hardhat config (these have funds)
ETH_KEYS=(
    "0xc5e8f61d1ab959b397eecc0a37a6517b8e67a0e7cf1f4bce5591f3ed80199122"
    "0xd49743deccbccc5dc7baa8e69e5be03298da8688a15dd202e20f15d5e0e9a9fb"
    "0x23c601ae397441f3ef6f1075dcb0031ff17fb079837beadaf3c84d96c6f3e569"
    "0xee9d129c1997549ee09c0757af5939b2483d80ad649a0eda68e8b0357ad11131"
)

# Step 1: Build Cosmos module
echo -e "\n${YELLOW}Step 1: Building Cosmos module (gravity binary)...${NC}"
cd "$ROOT_DIR/module"
if [ ! -f "$GOPATH/bin/gravity" ] && [ ! -f "/usr/local/bin/gravity" ] && [ ! -f "$HOME/go/bin/gravity" ]; then
    make install
    echo -e "  ${GREEN}✓ gravity binary built${NC}"
else
    echo -e "  ${GREEN}✓ gravity binary already exists${NC}"
fi

# Find gravity binary
GRAVITY_BIN=$(which gravity 2>/dev/null || echo "$HOME/go/bin/gravity")
if [ ! -f "$GRAVITY_BIN" ]; then
    GRAVITY_BIN="$GOPATH/bin/gravity"
fi
echo -e "  Using: $GRAVITY_BIN"

# Step 2: Build Orchestrator
echo -e "\n${YELLOW}Step 2: Building Orchestrator (gbt binary)...${NC}"
cd "$ROOT_DIR/orchestrator"
if [ ! -f "target/release/gbt" ]; then
    cargo build --release --bin gbt
    echo -e "  ${GREEN}✓ gbt binary built${NC}"
else
    echo -e "  ${GREEN}✓ gbt binary already exists${NC}"
fi

# Step 3: Install Solidity dependencies
echo -e "\n${YELLOW}Step 3: Setting up Solidity contracts...${NC}"
cd "$ROOT_DIR/solidity"
if [ ! -d "node_modules" ]; then
    npm install
    echo -e "  ${GREEN}✓ npm dependencies installed${NC}"
else
    echo -e "  ${GREEN}✓ npm dependencies already installed${NC}"
fi

# Compile contracts
if [ ! -d "artifacts" ]; then
    npx hardhat compile
    echo -e "  ${GREEN}✓ contracts compiled${NC}"
else
    echo -e "  ${GREEN}✓ contracts already compiled${NC}"
fi

# Generate typechain
if [ ! -d "typechain" ]; then
    npm run typechain
    echo -e "  ${GREEN}✓ typechain generated${NC}"
else
    echo -e "  ${GREEN}✓ typechain already generated${NC}"
fi

# Step 4: Setup validator configuration
echo -e "\n${YELLOW}Step 4: Setting up validator configuration...${NC}"

CHAIN_ID="gravity-test-1"
NUM_VALIDATORS=4
DATA_DIR="$SCRIPT_DIR/data"

# Clean previous data
rm -rf "$DATA_DIR/validator"*
rm -rf "$DATA_DIR"/*.json
rm -rf "$DATA_DIR"/*.txt

# Initialize files
> "$DATA_DIR/validator-phrases.txt"
> "$DATA_DIR/orchestrator-phrases.txt"
> "$DATA_DIR/eth-keys.txt"

# Generate validators
for i in $(seq 1 $NUM_VALIDATORS); do
    VALIDATOR_HOME="$DATA_DIR/validator$i"
    mkdir -p "$VALIDATOR_HOME"

    # Initialize validator
    $GRAVITY_BIN init validator$i --chain-id=$CHAIN_ID --home="$VALIDATOR_HOME" 2>/dev/null

    # Create validator key and save mnemonic
    echo "Creating validator$i keys..."
    VALIDATOR_OUTPUT=$($GRAVITY_BIN keys add validator$i --keyring-backend test --home="$VALIDATOR_HOME" 2>&1)
    VALIDATOR_MNEMONIC=$(echo "$VALIDATOR_OUTPUT" | tail -1)
    echo "$VALIDATOR_MNEMONIC" >> "$DATA_DIR/validator-phrases.txt"

    # Create orchestrator key and save mnemonic
    ORCH_OUTPUT=$($GRAVITY_BIN keys add orchestrator$i --keyring-backend test --home="$VALIDATOR_HOME" 2>&1)
    ORCH_MNEMONIC=$(echo "$ORCH_OUTPUT" | tail -1)
    echo "$ORCH_MNEMONIC" >> "$DATA_DIR/orchestrator-phrases.txt"

    # Use pre-defined ethereum keys from hardhat config
    ETH_KEY="${ETH_KEYS[$((i-1))]}"
    ETH_ADDR=$(cd "$ROOT_DIR/solidity" && node -e "const {ethers} = require('ethers'); console.log(new ethers.Wallet('$ETH_KEY').address)")

    echo "Validator $i Ethereum Key:" >> "$DATA_DIR/eth-keys.txt"
    echo "  private_key: $ETH_KEY" >> "$DATA_DIR/eth-keys.txt"
    echo "  address: $ETH_ADDR" >> "$DATA_DIR/eth-keys.txt"
    echo "" >> "$DATA_DIR/eth-keys.txt"
done

echo -e "  ${GREEN}✓ Created $NUM_VALIDATORS validators${NC}"

# Step 5: Configure genesis
echo -e "\n${YELLOW}Step 5: Configuring genesis...${NC}"

GENESIS="$DATA_DIR/validator1/config/genesis.json"
ALLOCATION="1000000000000footoken,1000000000000ugraviton"

# Add denom metadata
jq '.app_state.bank.denom_metadata = [
  {"name": "Foo Token", "symbol": "FOO", "base": "footoken", "display": "mfootoken", "description": "A test token", "denom_units": [{"denom": "footoken", "exponent": 0}, {"denom": "mfootoken", "exponent": 6}]},
  {"name": "Graviton", "symbol": "GRAV", "base": "ugraviton", "display": "graviton", "description": "Staking token", "denom_units": [{"denom": "ugraviton", "exponent": 0}, {"denom": "graviton", "exponent": 6}]}
]' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"

# Set bech32 prefix
jq '.app_state.bech32ibc.nativeHRP = "gravity"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"

# Fast governance for testing (60 seconds)
jq '.app_state.gov.params.max_deposit_period = "60s"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.gov.params.voting_period = "60s"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"
jq '.app_state.gov.params.expedited_voting_period = "30s"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"

# Change stake to ugraviton
sed -i.bak 's/"stake"/"ugraviton"/g' "$GENESIS"
rm -f "$GENESIS.bak"

# Add genesis accounts for all validators
for i in $(seq 1 $NUM_VALIDATORS); do
    VALIDATOR_HOME="$DATA_DIR/validator$i"

    VALIDATOR_ADDR=$($GRAVITY_BIN keys show validator$i -a --keyring-backend test --home="$VALIDATOR_HOME")
    ORCHESTRATOR_ADDR=$($GRAVITY_BIN keys show orchestrator$i -a --keyring-backend test --home="$VALIDATOR_HOME")

    # Add to genesis
    $GRAVITY_BIN add-genesis-account $VALIDATOR_ADDR $ALLOCATION --home="$DATA_DIR/validator1" --keyring-backend test
    $GRAVITY_BIN add-genesis-account $ORCHESTRATOR_ADDR $ALLOCATION --home="$DATA_DIR/validator1" --keyring-backend test
done

echo -e "  ${GREEN}✓ Genesis configured${NC}"

# Step 6: Create gentxs
echo -e "\n${YELLOW}Step 6: Creating genesis transactions...${NC}"

for i in $(seq 1 $NUM_VALIDATORS); do
    VALIDATOR_HOME="$DATA_DIR/validator$i"

    # Copy genesis to validator (skip for validator1 - it's the source)
    if [ $i -gt 1 ]; then
        cp "$DATA_DIR/validator1/config/genesis.json" "$VALIDATOR_HOME/config/genesis.json"
    fi

    # Get ethereum address for this validator from pre-defined keys
    ETH_KEY="${ETH_KEYS[$((i-1))]}"
    ETH_ADDR=$(cd "$ROOT_DIR/solidity" && node -e "const {ethers} = require('ethers'); console.log(new ethers.Wallet('$ETH_KEY').address)")

    ORCHESTRATOR_ADDR=$($GRAVITY_BIN keys show orchestrator$i -a --keyring-backend test --home="$VALIDATOR_HOME")

    echo "  Creating gentx for validator$i (ETH: $ETH_ADDR)"

    # Create gentx
    $GRAVITY_BIN gentx validator$i 500000000ugraviton "$ETH_ADDR" "$ORCHESTRATOR_ADDR" \
        --chain-id=$CHAIN_ID \
        --keyring-backend test \
        --home="$VALIDATOR_HOME" \
        --moniker="validator$i" \
        --ip="127.0.0.1"

    # Copy gentx to validator1
    if [ $i -gt 1 ]; then
        cp "$VALIDATOR_HOME/config/gentx/"* "$DATA_DIR/validator1/config/gentx/"
    fi
done

# Collect gentxs
$GRAVITY_BIN collect-gentxs --home="$DATA_DIR/validator1"

# Copy final genesis to all validators
for i in $(seq 2 $NUM_VALIDATORS); do
    cp "$DATA_DIR/validator1/config/genesis.json" "$DATA_DIR/validator$i/config/genesis.json"
done

echo -e "  ${GREEN}✓ Genesis transactions created${NC}"

# Step 7: Configure networking
echo -e "\n${YELLOW}Step 7: Configuring networking...${NC}"

# Get all node IDs first
declare -a NODE_IDS
for i in $(seq 1 $NUM_VALIDATORS); do
    NODE_IDS[$i]=$($GRAVITY_BIN tendermint show-node-id --home="$DATA_DIR/validator$i")
done

for i in $(seq 1 $NUM_VALIDATORS); do
    VALIDATOR_HOME="$DATA_DIR/validator$i"
    CONFIG="$VALIDATOR_HOME/config/config.toml"
    APP_CONFIG="$VALIDATOR_HOME/config/app.toml"

    # Calculate ports (offset by validator number)
    RPC_PORT=$((26657 + (i-1)*100))
    P2P_PORT=$((26656 + (i-1)*100))
    GRPC_PORT=$((9090 + (i-1)*10))
    API_PORT=$((1317 + (i-1)*10))
    PPROF_PORT=$((6060 + (i-1)*10))

    # Update config.toml - RPC
    sed -i.bak "s|laddr = \"tcp://127.0.0.1:26657\"|laddr = \"tcp://0.0.0.0:$RPC_PORT\"|" "$CONFIG"

    # Update config.toml - P2P
    sed -i.bak "s|laddr = \"tcp://0.0.0.0:26656\"|laddr = \"tcp://0.0.0.0:$P2P_PORT\"|" "$CONFIG"

    # Update pprof port
    sed -i.bak "s|pprof_laddr = \"localhost:6060\"|pprof_laddr = \"localhost:$PPROF_PORT\"|" "$CONFIG"

    # Build persistent peers list (connect to all OTHER validators)
    PEERS=""
    for j in $(seq 1 $NUM_VALIDATORS); do
        if [ $j -ne $i ]; then
            PEER_P2P_PORT=$((26656 + (j-1)*100))
            if [ -n "$PEERS" ]; then
                PEERS="$PEERS,"
            fi
            PEERS="${PEERS}${NODE_IDS[$j]}@127.0.0.1:$PEER_P2P_PORT"
        fi
    done

    # Set persistent peers
    sed -i.bak "s|persistent_peers = \"\"|persistent_peers = \"$PEERS\"|" "$CONFIG"

    # Allow duplicate IPs (for local testing)
    sed -i.bak 's|allow_duplicate_ip = false|allow_duplicate_ip = true|' "$CONFIG"

    # Enable prometheus
    sed -i.bak 's|prometheus = false|prometheus = true|' "$CONFIG"

    # Update app.toml - gRPC
    sed -i.bak "s|address = \"0.0.0.0:9090\"|address = \"0.0.0.0:$GRPC_PORT\"|" "$APP_CONFIG"
    sed -i.bak "s|address = \"localhost:9090\"|address = \"0.0.0.0:$GRPC_PORT\"|" "$APP_CONFIG"

    # Update app.toml - API
    sed -i.bak "s|address = \"tcp://localhost:1317\"|address = \"tcp://0.0.0.0:$API_PORT\"|" "$APP_CONFIG"

    # Enable API
    sed -i.bak 's|enable = false|enable = true|' "$APP_CONFIG"

    rm -f "$CONFIG.bak" "$APP_CONFIG.bak"

    echo "  Validator $i: RPC=$RPC_PORT, P2P=$P2P_PORT, gRPC=$GRPC_PORT"
done

echo -e "  ${GREEN}✓ Networking configured${NC}"

# Step 8: Save configuration summary
echo -e "\n${YELLOW}Step 8: Saving configuration...${NC}"

cat > "$SCRIPT_DIR/config/local-config.json" << EOF
{
  "chain_id": "$CHAIN_ID",
  "num_validators": $NUM_VALIDATORS,
  "cosmos": {
    "rpc": "http://localhost:26657",
    "grpc": "http://localhost:9090",
    "api": "http://localhost:1317"
  },
  "ethereum": {
    "rpc": "http://localhost:8545",
    "chain_id": 31337
  },
  "gravity_binary": "$GRAVITY_BIN",
  "orchestrator_binary": "$ROOT_DIR/orchestrator/target/release/gbt",
  "data_dir": "$DATA_DIR"
}
EOF

# Extract and save key information
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Validator Addresses:${NC}"
for i in $(seq 1 $NUM_VALIDATORS); do
    VALIDATOR_HOME="$DATA_DIR/validator$i"
    ADDR=$($GRAVITY_BIN keys show validator$i -a --keyring-backend test --home="$VALIDATOR_HOME")
    echo "  Validator $i: $ADDR"
done

echo -e "\n${YELLOW}Orchestrator Addresses:${NC}"
for i in $(seq 1 $NUM_VALIDATORS); do
    VALIDATOR_HOME="$DATA_DIR/validator$i"
    ADDR=$($GRAVITY_BIN keys show orchestrator$i -a --keyring-backend test --home="$VALIDATOR_HOME")
    echo "  Orchestrator $i: $ADDR"
done

echo -e "\n${YELLOW}Ethereum Addresses:${NC}"
cat "$DATA_DIR/eth-keys.txt" | grep "address:" | head -$NUM_VALIDATORS | nl

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "  1. Run: ./start.sh"
echo "  2. Wait for chains to start"
echo "  3. Run: ./test-deposit.sh"
