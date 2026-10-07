# Local Gravity Bridge Setup

This directory contains scripts to run a complete local Gravity Bridge with:
- Local Cosmos chain (gravity-test-1)
- Local Ethereum chain (Hardhat)
- Orchestrators for all validators
- Full deposit and withdrawal functionality

## Prerequisites

```bash
# Install required tools
brew install go rust node jq

# Verify versions
go version      # 1.21+
cargo --version # 1.70+
node --version  # 18+
```

## Quick Start

```bash
# 1. Setup everything (one-time)
./setup.sh

# 2. Start the bridge
./start.sh

# 3. Test deposit (ETH -> Cosmos)
./test-deposit.sh

# 4. Test withdrawal (Cosmos -> ETH)
./test-withdraw.sh

# 5. Stop everything
./stop.sh
```

## Directory Structure

```
local-bridge/
├── README.md           # This file
├── setup.sh            # One-time setup (builds binaries)
├── start.sh            # Start all components
├── stop.sh             # Stop all components
├── test-deposit.sh     # Test ETH -> Cosmos transfer
├── test-withdraw.sh    # Test Cosmos -> ETH transfer
├── config/             # Configuration files
└── data/               # Runtime data (validators, keys, logs)
```

## Components

| Component | Port | Description |
|-----------|------|-------------|
| Cosmos RPC | 26657 | Tendermint RPC |
| Cosmos gRPC | 9090 | gRPC endpoint |
| Cosmos REST | 1317 | REST API |
| Ethereum RPC | 8545 | Hardhat JSON-RPC |

## Accounts

### Ethereum (Hardhat default accounts)
- Miner: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` (10000 ETH)
- Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

### Cosmos
- Validators: `gravity1...` (created during setup)
- Each has 1000000000 ugraviton + footoken
