#!/bin/bash

# Gravity Bridge: Ethereum Sepolia ↔ Gravity Bridge Mainnet
# Orchestrator Launch Script

echo "=========================================="
echo "Gravity Bridge Orchestrator"
echo "Sepolia → Gravity Bridge Mainnet"
echo "=========================================="
echo ""

# Check if deployment info exists
DEPLOYMENT_FILE="../solidity/sepolia-gravity-mainnet-deployment.json"
if [ -f "$DEPLOYMENT_FILE" ]; then
    echo "📋 Found deployment info file"
    GRAVITY_CONTRACT=$(cat "$DEPLOYMENT_FILE" | grep -o '"gravityContract": "[^"]*' | cut -d'"' -f4)
    DEPLOYMENT_BLOCK=$(cat "$DEPLOYMENT_FILE" | grep -o '"deploymentBlock": [0-9]*' | cut -d':' -f2 | tr -d ' ')
    echo "   Contract: $GRAVITY_CONTRACT"
    echo "   Deployment Block: $DEPLOYMENT_BLOCK"
    echo ""
fi

# Configuration - UPDATE THESE VALUES
echo "⚙️  Configuration:"
echo ""

# Ethereum Sepolia Configuration
ETHEREUM_RPC="${ETHEREUM_RPC:-https://ethereum-sepolia-rpc.publicnode.com}"
ETHEREUM_PRIVATE_KEY="${ETHEREUM_PRIVATE_KEY}"

# Use contract from deployment file if available
if [ -z "$GRAVITY_CONTRACT_ADDRESS" ] && [ ! -z "$GRAVITY_CONTRACT" ]; then
    GRAVITY_CONTRACT_ADDRESS="$GRAVITY_CONTRACT"
fi

GRAVITY_CONTRACT_ADDRESS="${GRAVITY_CONTRACT_ADDRESS}"

echo "Ethereum RPC: $ETHEREUM_RPC"
if [ -z "$ETHEREUM_PRIVATE_KEY" ]; then
    echo "Ethereum Key: ❌ NOT SET"
else
    echo "Ethereum Key: ✅ SET"
fi

if [ -z "$GRAVITY_CONTRACT_ADDRESS" ]; then
    echo "Gravity Contract: ❌ NOT SET"
else
    echo "Gravity Contract: $GRAVITY_CONTRACT_ADDRESS"
fi

# Gravity Bridge Mainnet Configuration
COSMOS_GRPC="${COSMOS_GRPC:-https://gravitychain.io:9090}"
COSMOS_PHRASE="${COSMOS_PHRASE}"

echo ""
echo "Cosmos gRPC: $COSMOS_GRPC"
if [ -z "$COSMOS_PHRASE" ]; then
    echo "Cosmos Phrase: ❌ NOT SET"
else
    echo "Cosmos Phrase: ✅ SET"
fi

# Fees
FEES="${FEES:-0ugraviton}"
echo ""
echo "Transaction Fees: $FEES"
echo ""

# Validation
if [ -z "$ETHEREUM_PRIVATE_KEY" ]; then
    echo "❌ Error: ETHEREUM_PRIVATE_KEY environment variable not set"
    echo ""
    echo "Usage:"
    echo "  export ETHEREUM_PRIVATE_KEY=0x..."
    echo "  export COSMOS_PHRASE=\"your twelve word mnemonic...\""
    echo "  export GRAVITY_CONTRACT_ADDRESS=0x..."
    echo "  ./run-sepolia-mainnet.sh"
    echo ""
    exit 1
fi

if [ -z "$COSMOS_PHRASE" ]; then
    echo "❌ Error: COSMOS_PHRASE environment variable not set"
    echo ""
    echo "Usage:"
    echo "  export ETHEREUM_PRIVATE_KEY=0x..."
    echo "  export COSMOS_PHRASE=\"your twelve word mnemonic...\""
    echo "  export GRAVITY_CONTRACT_ADDRESS=0x..."
    echo "  ./run-sepolia-mainnet.sh"
    echo ""
    exit 1
fi

if [ -z "$GRAVITY_CONTRACT_ADDRESS" ]; then
    echo "❌ Error: GRAVITY_CONTRACT_ADDRESS environment variable not set"
    echo ""
    echo "Usage:"
    echo "  export ETHEREUM_PRIVATE_KEY=0x..."
    echo "  export COSMOS_PHRASE=\"your twelve word mnemonic...\""
    echo "  export GRAVITY_CONTRACT_ADDRESS=0x..."
    echo "  ./run-sepolia-mainnet.sh"
    echo ""
    exit 1
fi

# Check if binary exists
if [ ! -f "./target/release/gbt" ]; then
    echo "❌ Error: Orchestrator binary not found"
    echo ""
    echo "Please build the orchestrator first:"
    echo "  cargo build --release --bin gbt"
    echo ""
    exit 1
fi

# Reminder about oracle_resync.rs
if [ ! -z "$DEPLOYMENT_BLOCK" ]; then
    echo "=========================================="
    echo "⚠️  IMPORTANT REMINDER"
    echo "=========================================="
    echo ""
    echo "Make sure you updated oracle_resync.rs with the deployment block!"
    echo ""
    echo "File: orchestrator/src/oracle_resync.rs"
    echo "Lines to update: 46 and 56"
    echo "Change to: let start_block: Uint256 = ${DEPLOYMENT_BLOCK}u128.into();"
    echo ""
    echo "Then rebuild:"
    echo "  cargo build --release --bin gbt"
    echo ""
    read -p "Have you done this? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please update oracle_resync.rs and rebuild, then run this script again."
        exit 1
    fi
fi

echo "=========================================="
echo "🚀 Starting Orchestrator..."
echo "=========================================="
echo ""

# Start orchestrator
./target/release/gbt orchestrator \
  --cosmos-grpc "$COSMOS_GRPC" \
  --ethereum-rpc "$ETHEREUM_RPC" \
  --ethereum-key "$ETHEREUM_PRIVATE_KEY" \
  --cosmos-phrase "$COSMOS_PHRASE" \
  --fees "$FEES" \
  --gravity-contract-address "$GRAVITY_CONTRACT_ADDRESS"
