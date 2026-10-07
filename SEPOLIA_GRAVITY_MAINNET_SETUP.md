# Gravity Bridge: Ethereum Sepolia ↔ Gravity Bridge Mainnet

## **Complete Step-by-Step Implementation Guide**

This guide walks you through deploying and operating a Gravity Bridge between Ethereum Sepolia testnet and Gravity Bridge mainnet.

---

## **Prerequisites**

### **Required Tokens & Accounts**

1. **Ethereum Sepolia Testnet**
   - Sepolia ETH for gas fees (get from [Sepolia Faucet](https://sepoliafaucet.com/))
   - An Ethereum private key with Sepolia ETH

2. **Gravity Bridge Mainnet**
   - GRAV tokens for transaction fees
   - A Cosmos mnemonic phrase
   - Note: Gravity Bridge mainnet uses real tokens but they have low value (~$0.01)

3. **Development Tools**
   - Node.js and npm installed
   - Rust and Cargo installed (for orchestrator)
   - This Gravity Bridge repository compiled

### **Network Information**

**Gravity Bridge Mainnet:**
- Chain ID: `gravity-bridge-3`
- RPC: `https://gravitychain.io:26657`
- REST API: `https://gravitychain.io:1317`
- gRPC: `gravitychain.io:9090`
- Current Validators: 40
- Gravity ID: `gravity-bridge-mainnet`
- Existing Ethereum Mainnet Bridge: `0xa4108aA1Ec4967F8b52220a4f7e94A8201F2D906` (Chain ID: 1)

**Ethereum Sepolia:**
- Chain ID: `11155111`
- RPC: `https://ethereum-sepolia-rpc.publicnode.com` (or your preferred provider)

---

## **Important Understanding**

Since Gravity Bridge mainnet already has an active bridge to Ethereum mainnet (not Sepolia), you have **two options**:

### **Option A: Deploy a NEW Gravity Contract to Sepolia (Parallel Bridge)**
- Deploy your own Gravity.sol contract to Sepolia
- This creates a NEW bridge instance specifically for testing
- Requires validator participation (you'll run your own orchestrator)
- **Limitation**: Without other validators signing, you can't actually execute batches
- **Best for**: Understanding deployment and architecture

### **Option B: Use Existing Mainnet Bridge (Production)**
- Use the existing Gravity Bridge between Ethereum Mainnet ↔ Gravity Bridge Mainnet
- This is the live, production bridge
- Fully functional with real validators
- **Best for**: Actual bridging operations

---

## **RECOMMENDED APPROACH: Use Existing Mainnet Bridge**

For practical bridging experience, I recommend using the existing production bridge between Ethereum Mainnet and Gravity Bridge mainnet. However, I'll document both approaches.

---

# **APPROACH 1: Deploy to Sepolia (Educational/Testing)**

This approach lets you deploy contracts and understand the architecture, but won't allow full bridging without multiple validators.

## **Step 1: Get Testnet Tokens**

### **1.1 Get Sepolia ETH**

```bash
# Visit Sepolia faucet and get testnet ETH
https://sepoliafaucet.com/
# or
https://www.alchemy.com/faucets/ethereum-sepolia
```

### **1.2 Get GRAV Tokens**

**Option 1: Buy small amount on exchange**
- GRAV tokens are available on Osmosis, Crescent, and other DEXs
- Minimum: ~1 GRAV (~$0.01) is enough for testing

**Option 2: Ask in community**
- Join [Gravity Bridge Discord](https://discord.gg/d3DshmHpXA)
- Request small amount for testing in #faucet or #general

### **1.3 Set Up Cosmos Wallet**

```bash
# Install gravity binary
cd module
make install

# Create new wallet or import existing
gravity keys add mykey --keyring-backend test

# Or import existing mnemonic
echo "your mnemonic phrase here" | gravity keys add mykey --recover --keyring-backend test

# Get your address
gravity keys show mykey -a --keyring-backend test
# Example output: gravity1abcd...xyz
```

---

## **Step 2: Modify Contract Deployer for Gravity Mainnet**

Create a modified deployment script that connects to Gravity Bridge mainnet.

### **2.1 Create Modified Deployment Script**

Create file: `solidity/deploy-sepolia-gravity-mainnet.ts`

```typescript
import { Gravity } from "./typechain/Gravity";
import { GravityERC721 } from "./typechain/GravityERC721";
import { ethers } from "ethers";
import fs from "fs";
import axios from "axios";

// Configuration
const SEPOLIA_RPC = process.env.SEPOLIA_RPC || "https://ethereum-sepolia-rpc.publicnode.com";
const SEPOLIA_PRIVATE_KEY = process.env.SEPOLIA_PRIVATE_KEY;
const GRAVITY_REST_API = "https://gravitychain.io:1317";

type Validator = {
  power: string;
  ethereum_address: string;
};

type Valset = {
  members: Validator[];
  nonce: string;
};

async function main() {
  console.log("\n=== Deploying Gravity Bridge to Sepolia ===\n");

  if (!SEPOLIA_PRIVATE_KEY) {
    console.error("Error: SEPOLIA_PRIVATE_KEY environment variable not set");
    process.exit(1);
  }

  // Connect to Sepolia
  const provider = new ethers.providers.JsonRpcProvider(SEPOLIA_RPC);
  const wallet = new ethers.Wallet(SEPOLIA_PRIVATE_KEY, provider);

  console.log(`Deployer address: ${wallet.address}`);

  // Check balance
  const balance = await wallet.getBalance();
  console.log(`Sepolia ETH balance: ${ethers.utils.formatEther(balance)} ETH\n`);

  if (balance.lt(ethers.utils.parseEther("0.1"))) {
    console.error("Warning: Low balance. You need at least 0.1 Sepolia ETH for deployment");
  }

  // Get Gravity Bridge mainnet parameters
  console.log("Fetching Gravity Bridge mainnet parameters...");
  const paramsResponse = await axios.get(`${GRAVITY_REST_API}/gravity/v1beta/params`);
  const gravityId = paramsResponse.data.params.gravity_id;
  console.log(`Gravity ID: ${gravityId}`);

  // Get current validator set from Gravity Bridge mainnet
  console.log("Fetching current validator set from Gravity Bridge mainnet...");
  const valsetResponse = await axios.get(`${GRAVITY_REST_API}/gravity/v1beta/valset/current`);
  const valset: Valset = valsetResponse.data.valset;

  console.log(`Validator set nonce: ${valset.nonce}`);
  console.log(`Number of validators: ${valset.members.length}\n`);

  // Prepare validator data for contract
  const eth_addresses: string[] = [];
  const powers: number[] = [];
  let powers_sum = 0;

  for (const member of valset.members) {
    if (member.ethereum_address && member.ethereum_address !== "") {
      eth_addresses.push(member.ethereum_address);
      const power = parseInt(member.power);
      powers.push(power);
      powers_sum += power;
    }
  }

  console.log(`Validators with Ethereum addresses: ${eth_addresses.length}`);
  console.log(`Total voting power: ${powers_sum}\n`);

  // Check if we have enough voting power (66% of uint32_max)
  const required_power = 2834678415;
  if (powers_sum < required_power) {
    console.error("Error: Insufficient voting power from validators with Ethereum addresses");
    console.error(`Required: ${required_power}, Got: ${powers_sum}`);
    process.exit(1);
  }

  // Deploy Gravity contract
  console.log("Deploying Gravity contract to Sepolia...");
  const gravityArtifact = JSON.parse(
    fs.readFileSync("artifacts/contracts/Gravity.sol/Gravity.json", "utf8")
  );

  const gravityFactory = new ethers.ContractFactory(
    gravityArtifact.abi,
    gravityArtifact.bytecode,
    wallet
  );

  const gravityIdBytes32 = ethers.utils.formatBytes32String(gravityId);

  const gravity = (await gravityFactory.deploy(
    gravityIdBytes32,
    eth_addresses,
    powers
  )) as Gravity;

  console.log("Waiting for deployment transaction to be mined...");
  await gravity.deployed();

  const deploymentBlock = gravity.deployTransaction.blockNumber;

  console.log("\n=== Deployment Successful ===");
  console.log(`Gravity contract address: ${gravity.address}`);
  console.log(`Deployed at block: ${deploymentBlock}`);
  console.log(`View on Etherscan: https://sepolia.etherscan.io/address/${gravity.address}`);
  console.log(`Transaction: https://sepolia.etherscan.io/tx/${gravity.deployTransaction.hash}\n`);

  // Deploy GravityERC721
  console.log("Deploying GravityERC721 contract...");
  const erc721Artifact = JSON.parse(
    fs.readFileSync("artifacts/contracts/GravityERC721.sol/GravityERC721.json", "utf8")
  );

  const erc721Factory = new ethers.ContractFactory(
    erc721Artifact.abi,
    erc721Artifact.bytecode,
    wallet
  );

  const gravityERC721 = (await erc721Factory.deploy(gravity.address)) as GravityERC721;
  await gravityERC721.deployed();

  console.log(`GravityERC721 contract address: ${gravityERC721.address}`);
  console.log(`View on Etherscan: https://sepolia.etherscan.io/address/${gravityERC721.address}\n`);

  // Save deployment info
  const deploymentInfo = {
    network: "sepolia",
    gravityChainId: "gravity-bridge-3",
    ethereumChainId: 11155111,
    gravityContract: gravity.address,
    gravityERC721Contract: gravityERC721.address,
    deploymentBlock: deploymentBlock,
    deploymentTx: gravity.deployTransaction.hash,
    gravityId: gravityId,
    timestamp: new Date().toISOString()
  };

  fs.writeFileSync(
    "sepolia-gravity-mainnet-deployment.json",
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("Deployment info saved to: sepolia-gravity-mainnet-deployment.json\n");

  console.log("=== Next Steps ===");
  console.log("1. Update orchestrator configuration with the contract address above");
  console.log(`2. Modify orchestrator/orchestrator/src/oracle_resync.rs to start from block ${deploymentBlock}`);
  console.log("3. Rebuild the orchestrator: cd orchestrator && cargo build --release --bin gbt");
  console.log("4. Start the orchestrator with both Sepolia and Gravity Bridge mainnet endpoints");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

---

## **Step 3: Deploy Contracts to Sepolia**

### **3.1 Compile Contracts**

```bash
cd solidity
npx hardhat compile
```

### **3.2 Run Deployment Script**

```bash
# Set your private key
export SEPOLIA_PRIVATE_KEY="0x_your_private_key_here"

# Run deployment
npx ts-node deploy-sepolia-gravity-mainnet.ts
```

**Expected Output:**
```
=== Deploying Gravity Bridge to Sepolia ===

Deployer address: 0x...
Sepolia ETH balance: 0.5 ETH

Fetching Gravity Bridge mainnet parameters...
Gravity ID: gravity-bridge-mainnet
Fetching current validator set from Gravity Bridge mainnet...
Validator set nonce: 1234
Number of validators: 40

Validators with Ethereum addresses: 38
Total voting power: 4234567890

Deploying Gravity contract to Sepolia...
Waiting for deployment transaction to be mined...

=== Deployment Successful ===
Gravity contract address: 0x...
Deployed at block: 10123456
View on Etherscan: https://sepolia.etherscan.io/address/0x...
```

**Save the following information:**
- Gravity contract address
- Deployment block number

---

## **Step 4: Update Orchestrator Configuration**

### **4.1 Modify Oracle Resync Block**

Edit: `orchestrator/orchestrator/src/oracle_resync.rs`

Replace the hardcoded block number with your deployment block:

```rust
// Line 44-50: Update with YOUR deployment block
if last_event_nonce == 0u8.into() {
    let start_block: Uint256 = YOUR_DEPLOYMENT_BLOCK.into(); // Update this!
    warn!("Last event nonce is 0 - this oracle has never submitted an event");
    warn!("Starting from block {} to catch all Gravity contract events", start_block);
    return start_block;
}

// Line 54-59: Also update for event nonce 1
if last_event_nonce == 1u8.into() {
    let start_block: Uint256 = YOUR_DEPLOYMENT_BLOCK.into(); // Update this!
    warn!("Last event nonce is 1 - starting from Gravity contract deployment block");
    warn!("Starting from block {}", start_block);
    return start_block;
}
```

### **4.2 Rebuild Orchestrator**

```bash
cd orchestrator
cargo build --release --bin gbt
```

---

## **Step 5: Configure and Start Orchestrator**

### **5.1 Set Up Environment Variables**

Create a file `orchestrator/run-sepolia-mainnet.sh`:

```bash
#!/bin/bash

# Ethereum Sepolia Configuration
export ETHEREUM_RPC="https://ethereum-sepolia-rpc.publicnode.com"
export ETHEREUM_PRIVATE_KEY="0x_your_ethereum_private_key"
export GRAVITY_CONTRACT_ADDRESS="0x_your_deployed_gravity_contract_address"

# Gravity Bridge Mainnet Configuration
export COSMOS_GRPC="https://gravitychain.io:9090"
export COSMOS_PHRASE="your twelve or twenty-four word mnemonic phrase here"

# Fees
export FEES="0ugraviton"

# Start orchestrator
./target/release/gbt orchestrator \
  --cosmos-grpc "$COSMOS_GRPC" \
  --ethereum-rpc "$ETHEREUM_RPC" \
  --ethereum-key "$ETHEREUM_PRIVATE_KEY" \
  --cosmos-phrase "$COSMOS_PHRASE" \
  --fees "$FEES" \
  --gravity-contract-address "$GRAVITY_CONTRACT_ADDRESS"
```

Make it executable:

```bash
chmod +x run-sepolia-mainnet.sh
```

### **5.2 Start the Orchestrator**

```bash
./run-sepolia-mainnet.sh
```

**Expected Output:**

```
[INFO] Starting Gravity Validator companion binary Relayer + Oracle + Eth Signer
[INFO] Ethereum Address: 0x... Cosmos Address gravity1...
[INFO] Successfully connected to Ethereum RPC at latest block 10123500
[INFO] Oracle resync complete, Oracle now operational
```

---

## **Step 6: Deploy Test ERC20 Token on Sepolia**

Create file: `solidity/scripts/deploy-test-token-sepolia.ts`

```typescript
import { ethers } from "ethers";
import fs from "fs";

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(
    process.env.SEPOLIA_RPC || "https://ethereum-sepolia-rpc.publicnode.com"
  );

  const wallet = new ethers.Wallet(process.env.SEPOLIA_PRIVATE_KEY!, provider);

  console.log("\n=== Deploying Test Token to Sepolia ===\n");
  console.log(`Deployer: ${wallet.address}`);

  const artifactPath = "artifacts/contracts/TestToken.sol/TestToken.json";
  const { abi, bytecode } = JSON.parse(fs.readFileSync(artifactPath, "utf8"));

  const factory = new ethers.ContractFactory(abi, bytecode, wallet);
  const token = await factory.deploy(
    "Test Bridge Token",
    "TBT",
    wallet.address,
    "1000000" // 1 million tokens
  );

  await token.deployed();

  console.log(`Token deployed at: ${token.address}`);
  console.log(`View on Etherscan: https://sepolia.etherscan.io/address/${token.address}`);

  const balance = await token.balanceOf(wallet.address);
  console.log(`Your balance: ${ethers.utils.formatUnits(balance, 18)} TBT`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

Deploy:

```bash
npx ts-node scripts/deploy-test-token-sepolia.ts
```

---

## **Step 7: Test Bridging (Sepolia → Gravity Bridge)**

### **7.1 Send Tokens from Sepolia to Gravity Bridge**

```bash
cd orchestrator

./target/release/gbt client eth-to-cosmos \
  --ethereum-key "0x_your_private_key" \
  --ethereum-rpc https://ethereum-sepolia-rpc.publicnode.com \
  --gravity-contract-address YOUR_GRAVITY_CONTRACT_ADDRESS \
  --token-contract-address YOUR_TEST_TOKEN_ADDRESS \
  --amount 100 \
  --destination YOUR_GRAVITY_ADDRESS
```

### **7.2 Monitor Orchestrator Logs**

Watch for deposit events:

```
[INFO] Oracle observed deposit with sender 0x..., destination Some(gravity1...),
      amount 100000000000000000000, and event nonce 2
[INFO] Claims processed, new nonce 2
```

### **7.3 Verify on Gravity Bridge**

```bash
# Query balance on Gravity Bridge mainnet
gravity query bank balances YOUR_GRAVITY_ADDRESS \
  --node https://gravitychain.io:26657
```

---

## **CRITICAL LIMITATION FOR SEPOLIA DEPLOYMENT**

**⚠️ Important**: When you deploy to Sepolia, you're creating a NEW bridge instance that's separate from the mainnet validators. This means:

1. **Only YOUR orchestrator** will sign batches
2. **You can't execute batches** because the contract requires signatures from mainnet validators
3. **Sepolia → Gravity will work** (deposits are permissionless)
4. **Gravity → Sepolia won't work** without other validators signing

This setup is **educational only** - you can see how deposits work but can't complete the full cycle.

---

# **APPROACH 2: Use Existing Mainnet Bridge (RECOMMENDED for Production)**

For actual bridging functionality, use the existing production bridge.

## **Prerequisites**

- Real ETH on Ethereum mainnet (for gas)
- GRAV tokens on Gravity Bridge mainnet
- ERC20 tokens you want to bridge

## **Using the Existing Bridge**

### **Bridge from Ethereum Mainnet → Gravity Bridge**

```bash
./target/release/gbt client eth-to-cosmos \
  --ethereum-key "0x_your_private_key" \
  --ethereum-rpc https://eth.llamarpc.com \
  --gravity-contract-address 0xa4108aA1Ec4967F8b52220a4f7e94A8201F2D906 \
  --token-contract-address TOKEN_ADDRESS \
  --amount AMOUNT \
  --destination YOUR_GRAVITY_ADDRESS
```

### **Bridge from Gravity Bridge → Ethereum Mainnet**

```bash
./target/release/gbt client cosmos-to-eth \
  --cosmos-phrase "your mnemonic" \
  --cosmos-grpc https://gravitychain.io:9090 \
  --amount AMOUNTgravity0xTOKEN_ADDRESS \
  --fee 0ugraviton \
  --bridge-fee BRIDGE_FEE \
  --chain-fee CHAIN_FEE \
  --eth-destination YOUR_ETH_ADDRESS
```

---

## **Summary**

| Aspect | Sepolia Deployment | Mainnet Bridge |
|--------|-------------------|----------------|
| **Cost** | Testnet ETH (free) | Real ETH (expensive) |
| **Functionality** | Deposits only | Full bidirectional |
| **Purpose** | Learning/testing | Production use |
| **Validators** | Only you | 40+ validators |
| **Recommended for** | Understanding architecture | Actual bridging |

---

## **Troubleshooting**

### **Orchestrator Not Detecting Deposits**

1. Check Sepolia finality (takes ~13 minutes)
2. Verify orchestrator is watching the correct contract address
3. Check orchestrator logs for errors

### **Can't Execute Batches on Sepolia**

This is expected - you need other validators to sign batches. Consider using mainnet bridge instead.

### **Low Balance Errors**

- Sepolia: Get more from faucets
- Gravity Bridge: You need GRAV for transaction fees

---

## **Next Steps**

1. For learning: Deploy to Sepolia and observe deposit flow
2. For production: Use existing mainnet bridge with real tokens
3. For full testing: Set up multiple validators in a private testnet

---

## **Resources**

- [Gravity Bridge Documentation](https://www.gravitybridge.net/)
- [Sepolia Faucet](https://sepoliafaucet.com/)
- [Gravity Bridge Discord](https://discord.gg/d3DshmHpXA)
- [Etherscan Sepolia](https://sepolia.etherscan.io/)

---

**Created**: January 2026
**Repository**: Gravity Bridge
