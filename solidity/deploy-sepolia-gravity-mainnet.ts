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
    console.error("Usage: export SEPOLIA_PRIVATE_KEY=0x... && npx ts-node deploy-sepolia-gravity-mainnet.ts");
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
    console.error("Get Sepolia ETH from: https://sepoliafaucet.com/");
  }

  // Get Gravity Bridge mainnet parameters
  console.log("Fetching Gravity Bridge mainnet parameters...");
  try {
    const paramsResponse = await axios.get(`${GRAVITY_REST_API}/gravity/v1beta/params`);
    const gravityId = paramsResponse.data.params.gravity_id;
    const existingBridge = paramsResponse.data.params.bridge_ethereum_address;
    const bridgeChainId = paramsResponse.data.params.bridge_chain_id;

    console.log(`Gravity ID: ${gravityId}`);
    console.log(`Existing mainnet bridge: ${existingBridge} (Chain ID: ${bridgeChainId})`);
    console.log(`Note: You're deploying a NEW bridge instance to Sepolia\n`);

    // Get current validator set from Gravity Bridge mainnet
    console.log("Fetching current validator set from Gravity Bridge mainnet...");
    const valsetResponse = await axios.get(`${GRAVITY_REST_API}/gravity/v1beta/valset/current`);
    const valset: Valset = valsetResponse.data.valset;

    console.log(`Validator set nonce: ${valset.nonce}`);
    console.log(`Number of validators: ${valset.members.length}`);

    // Prepare validator data for contract
    const eth_addresses: string[] = [];
    const powers: number[] = [];
    let powers_sum = 0;

    for (const member of valset.members) {
      if (member.ethereum_address && member.ethereum_address !== "" && member.ethereum_address !== "0x0000000000000000000000000000000000000000") {
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
      console.error("\nThis means not enough validators have set their Ethereum addresses.");
      process.exit(1);
    }

    console.log("✅ Sufficient voting power for deployment\n");

    // Deploy Gravity contract
    console.log("Deploying Gravity contract to Sepolia...");
    console.log("This may take a few minutes...\n");

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

    const deploymentBlock = gravity.deployTransaction.blockNumber || 0;
    const deploymentTx = gravity.deployTransaction.hash;

    console.log("\n" + "=".repeat(60));
    console.log("🎉 DEPLOYMENT SUCCESSFUL");
    console.log("=".repeat(60));
    console.log(`Gravity contract: ${gravity.address}`);
    console.log(`Deployed at block: ${deploymentBlock}`);
    console.log(`Transaction: ${deploymentTx}`);
    console.log(`\nEtherscan: https://sepolia.etherscan.io/address/${gravity.address}`);
    console.log(`Transaction: https://sepolia.etherscan.io/tx/${deploymentTx}\n`);

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
    console.log("Waiting for GravityERC721 deployment...");
    await gravityERC721.deployed();

    console.log(`\n✅ GravityERC721: ${gravityERC721.address}`);
    console.log(`Etherscan: https://sepolia.etherscan.io/address/${gravityERC721.address}\n`);

    // Save deployment info
    const deploymentInfo = {
      network: "sepolia",
      ethereumChainId: 11155111,
      gravityChain: "gravity-bridge-3",
      gravityChainRPC: "https://gravitychain.io:26657",
      gravityChainGRPC: "https://gravitychain.io:9090",
      gravityContract: gravity.address,
      gravityERC721Contract: gravityERC721.address,
      deploymentBlock: deploymentBlock,
      deploymentTx: deploymentTx,
      gravityId: gravityId,
      deployerAddress: wallet.address,
      validatorCount: eth_addresses.length,
      totalVotingPower: powers_sum,
      timestamp: new Date().toISOString()
    };

    const filename = "sepolia-gravity-mainnet-deployment.json";
    fs.writeFileSync(filename, JSON.stringify(deploymentInfo, null, 2));

    console.log("=".repeat(60));
    console.log("📝 DEPLOYMENT INFO SAVED");
    console.log("=".repeat(60));
    console.log(`File: ${filename}\n`);

    console.log("=".repeat(60));
    console.log("📋 NEXT STEPS");
    console.log("=".repeat(60));
    console.log("\n1. Update oracle_resync.rs:");
    console.log(`   Replace block number with: ${deploymentBlock}`);
    console.log(`   File: orchestrator/orchestrator/src/oracle_resync.rs (lines 46 and 56)\n`);

    console.log("2. Rebuild orchestrator:");
    console.log("   cd orchestrator");
    console.log("   cargo build --release --bin gbt\n");

    console.log("3. Start orchestrator:");
    console.log("   ./target/release/gbt orchestrator \\");
    console.log("     --cosmos-grpc https://gravitychain.io:9090 \\");
    console.log("     --ethereum-rpc https://ethereum-sepolia-rpc.publicnode.com \\");
    console.log(`     --gravity-contract-address ${gravity.address} \\`);
    console.log("     --ethereum-key YOUR_ETH_PRIVATE_KEY \\");
    console.log("     --cosmos-phrase \"YOUR_COSMOS_MNEMONIC\" \\");
    console.log("     --fees 0ugraviton\n");

    console.log("4. Deploy test ERC20 token for bridging:");
    console.log("   npx ts-node scripts/deploy-test-token-sepolia.ts\n");

    console.log("=".repeat(60));
    console.log("⚠️  IMPORTANT LIMITATION");
    console.log("=".repeat(60));
    console.log("This deployment creates a NEW bridge instance to Sepolia.");
    console.log("Only YOUR orchestrator will sign batches.");
    console.log("\nWhat WILL work:");
    console.log("  ✅ Sepolia → Gravity Bridge (deposits)");
    console.log("\nWhat WON'T work:");
    console.log("  ❌ Gravity Bridge → Sepolia (withdrawals)");
    console.log("     (requires multiple validator signatures)\n");
    console.log("For full functionality, use the mainnet bridge or set up");
    console.log("multiple validators in a private testnet.\n");
    console.log("=".repeat(60));

  } catch (error: any) {
    console.error("\n❌ Deployment failed:");
    if (error.response) {
      console.error(`API Error: ${error.response.status} - ${error.response.statusText}`);
      console.error(`URL: ${error.config?.url}`);
    } else if (error.code === "INSUFFICIENT_FUNDS") {
      console.error("Insufficient Sepolia ETH for deployment");
      console.error("Get Sepolia ETH from: https://sepoliafaucet.com/");
    } else {
      console.error(error.message);
    }
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
