# Quick Start Guide: Sepolia ↔ Gravity Bridge Mainnet

This is the fast-track guide to get your bridge up and running. For detailed explanations, see `SEPOLIA_GRAVITY_MAINNET_SETUP.md`.

---

## **Prerequisites Checklist**

Before starting, make sure you have:

- [ ] Sepolia ETH (>0.2 ETH) - Get from [sepoliafaucet.com](https://sepoliafaucet.com/)
- [ ] GRAV tokens (~1 GRAV) - Ask in [Gravity Bridge Discord](https://discord.gg/d3DshmHpXA)
- [ ] Ethereum private key with Sepolia ETH
- [ ] Cosmos mnemonic phrase (12 or 24 words)
- [ ] Node.js installed
- [ ] Rust/Cargo installed
- [ ] This repository cloned and compiled

---

## **Step 1: Compile Contracts (2 minutes)**

```bash
cd solidity
npx hardhat compile
```

---

## **Step 2: Deploy to Sepolia (5 minutes)**

```bash
# Set your private key
export SEPOLIA_PRIVATE_KEY="0xYOUR_PRIVATE_KEY"

# Deploy Gravity contract
npx ts-node deploy-sepolia-gravity-mainnet.ts
```

**Save this output:**
- Gravity contract address: `0x...`
- Deployment block: `12345678`

---

## **Step 3: Update Oracle Resync Block (2 minutes)**

Edit: `orchestrator/orchestrator/src/oracle_resync.rs`

**Line 46** - Change to your deployment block:
```rust
let start_block: Uint256 = 12345678u128.into();  // <-- YOUR BLOCK HERE
```

**Line 56** - Same change:
```rust
let start_block: Uint256 = 12345678u128.into();  // <-- YOUR BLOCK HERE
```

---

## **Step 4: Build Orchestrator (5 minutes)**

```bash
cd orchestrator
cargo build --release --bin gbt
```

---

## **Step 5: Start Orchestrator (1 minute)**

```bash
# Set environment variables
export ETHEREUM_PRIVATE_KEY="0xYOUR_PRIVATE_KEY"
export COSMOS_PHRASE="your twelve word mnemonic phrase here"
export GRAVITY_CONTRACT_ADDRESS="0xYOUR_DEPLOYED_CONTRACT"

# Start orchestrator
./run-sepolia-mainnet.sh
```

**Expected output:**
```
[INFO] Starting Gravity Validator companion binary Relayer + Oracle + Eth Signer
[INFO] Ethereum Address: 0x... Cosmos Address gravity1...
[INFO] Oracle resync complete, Oracle now operational
```

**Keep this terminal running!**

---

## **Step 6: Deploy Test Token (2 minutes)**

Open a new terminal:

```bash
cd solidity
export SEPOLIA_PRIVATE_KEY="0xYOUR_PRIVATE_KEY"
npx ts-node scripts/deploy-test-erc20-sepolia.ts
```

**Save the token address:** `0x...`

---

## **Step 7: Test Deposit (Sepolia → Gravity Bridge)**

```bash
# Set environment
export SEPOLIA_PRIVATE_KEY="0xYOUR_PRIVATE_KEY"
export TOKEN_ADDRESS="0xYOUR_TOKEN_ADDRESS"
export GRAVITY_CONTRACT_ADDRESS="0xYOUR_GRAVITY_CONTRACT"
export DESTINATION_COSMOS_ADDRESS="gravity1YOUR_COSMOS_ADDRESS"
export AMOUNT="100"

# Send tokens
npx ts-node scripts/test-sepolia-deposit.ts
```

---

## **Step 8: Verify Receipt (~15 minutes)**

After Sepolia finality (~13 minutes), check your Cosmos balance:

```bash
gravity query bank balances gravity1YOUR_ADDRESS \
  --node https://gravitychain.io:26657
```

**Expected output:**
```yaml
balances:
- amount: "100000000000000000000"
  denom: gravity0xYOUR_TOKEN_ADDRESS
```

**Success!** 🎉

---

## **Troubleshooting**

### Orchestrator not detecting deposits
- Wait 15 minutes for Sepolia finality
- Check orchestrator is running
- Verify contract address matches deployment

### "Insufficient funds" error
- Get more Sepolia ETH from faucet
- Check you're using the right private key

### Can't query Cosmos balance
- Verify Cosmos address format (starts with `gravity1`)
- Check Gravity Bridge mainnet is accessible

---

## **Important Limitations**

✅ **What works:** Sepolia → Gravity Bridge (deposits)
❌ **What doesn't work:** Gravity Bridge → Sepolia (withdrawals)

**Why?** Your orchestrator is the only one signing batches. Withdrawals require multiple validator signatures from Gravity Bridge mainnet validators.

**For full bidirectional functionality:**
- Use the existing Ethereum Mainnet ↔ Gravity Bridge mainnet
- Or set up multiple validators in a private testnet

---

## **Next Steps**

- Read the full guide: `SEPOLIA_GRAVITY_MAINNET_SETUP.md`
- Join [Gravity Bridge Discord](https://discord.gg/d3DshmHpXA)
- Explore the codebase and modify for your needs

---

## **Command Reference**

### Deploy contracts:
```bash
npx ts-node deploy-sepolia-gravity-mainnet.ts
```

### Start orchestrator:
```bash
./run-sepolia-mainnet.sh
```

### Test deposit:
```bash
npx ts-node scripts/test-sepolia-deposit.ts
```

### Check Cosmos balance:
```bash
gravity query bank balances ADDRESS --node https://gravitychain.io:26657
```

### Using the gbt CLI directly:

**Deposit (Sepolia → Gravity):**
```bash
./target/release/gbt client eth-to-cosmos \
  --ethereum-key "0x..." \
  --ethereum-rpc https://ethereum-sepolia-rpc.publicnode.com \
  --gravity-contract-address 0x... \
  --token-contract-address 0x... \
  --amount 100 \
  --destination gravity1...
```

---

**Total setup time: ~20 minutes + 15 minutes for first deposit confirmation**

Good luck! 🚀
