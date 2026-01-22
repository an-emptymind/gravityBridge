import { ethers } from "ethers";
import fs from "fs";

async function main() {
  // Connect to your running node
  const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");

  // Account #0 private key (deployer)
  const deployerPrivateKey = "0xc5e8f61d1ab959b397eecc0a37a6517b8e67a0e7cf1f4bce5591f3ed80199122";
  const deployerWallet = new ethers.Wallet(deployerPrivateKey, provider);

  // Recipient address (your orchestrator's ETH address)
  const recipientAddress = "0x32cDc9954FF105339D4C9f96134E95fa66e619E8";

  // Token parameters
  const tokenName = "Test Bridge Token";
  const tokenSymbol = "TBT";
  const initialSupply = "1000000"; // 1 million tokens (will be multiplied by 10^18)

  console.log("\n=== Deploying New Test ERC20 Token ===\n");

  // Read the TestToken artifact
  const artifactPath = "artifacts/contracts/TestToken.sol/TestToken.json";

  if (!fs.existsSync(artifactPath)) {
    console.log("❌ Contract artifact not found. Compiling contracts...");
    console.log("   Please run: npx hardhat compile");
    console.log("   Then run this script again.");
    return;
  }

  const { abi, bytecode } = JSON.parse(fs.readFileSync(artifactPath, "utf8"));

  console.log("Deploying TestToken contract...");
  console.log(`Token Name: ${tokenName}`);
  console.log(`Token Symbol: ${tokenSymbol}`);
  console.log(`Initial Supply: ${initialSupply} tokens`);
  console.log(`Recipient: ${recipientAddress}`);
  console.log(`Deployer: ${deployerWallet.address}\n`);

  // Deploy the contract with constructor parameters
  const factory = new ethers.ContractFactory(abi, bytecode, deployerWallet);
  const contract = await factory.deploy(tokenName, tokenSymbol, recipientAddress, initialSupply);

  console.log("Waiting for deployment...");
  await contract.deployed();

  console.log(`\n✅ Token deployed at: ${contract.address}`);

  // Get token info
  const name = await contract.name();
  const symbol = await contract.symbol();
  const decimals = await contract.decimals();
  const totalSupply = await contract.totalSupply();

  console.log(`\n=== Token Information ===`);
  console.log(`Name: ${name}`);
  console.log(`Symbol: ${symbol}`);
  console.log(`Decimals: ${decimals}`);
  console.log(`Total Supply: ${ethers.utils.formatUnits(totalSupply, decimals)} ${symbol}`);

  // Check balance (all tokens were minted to recipient)
  const recipientBalance = await contract.balanceOf(recipientAddress);

  console.log(`\n=== Balances ===`);
  console.log(`Recipient (${recipientAddress}): ${ethers.utils.formatUnits(recipientBalance, decimals)} ${symbol}`);

  console.log(`\n=== Bridge Command ===`);
  console.log(`Use this command to bridge tokens to Cosmos:\n`);
  console.log(`cd /Users/Raghavendra/Raghav/gravityBridge/Gravity-Bridge/orchestrator`);
  console.log(`./target/release/gbt client eth-to-cosmos \\`);
  console.log(`  --ethereum-key "0xfade0465d16701288294fabb174bfc4f44808f203420e214ba13e2d4d503dd05" \\`);
  console.log(`  --ethereum-rpc http://127.0.0.1:8545 \\`);
  console.log(`  --gravity-contract-address 0xf4e77E5Da47AC3125140c470c71cBca77B5c638c \\`);
  console.log(`  --token-contract-address ${contract.address} \\`);
  console.log(`  --amount 10000 \\`);
  console.log(`  --destination gravity1wp4t6ka24dzjwgws0sveqtq67kamdm4zyet9xu\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
