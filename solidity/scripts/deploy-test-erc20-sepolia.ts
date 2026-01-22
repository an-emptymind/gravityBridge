import { ethers } from "ethers";
import fs from "fs";

async function main() {
  // Connect to Sepolia
  const alchemyApiKey = process.env.ALCHEMY_API_KEY || "YOUR_ALCHEMY_API_KEY";
  const provider = new ethers.providers.JsonRpcProvider(`https://eth-sepolia.g.alchemy.com/v2/${alchemyApiKey}`);

  // Your private key
  const deployerPrivateKey = process.env.SEPOLIA_PRIVATE_KEY || "YOUR_SEPOLIA_PRIVATE_KEY";
  const deployerWallet = new ethers.Wallet(deployerPrivateKey, provider);

  // Recipient address (deployer address - all tokens will be minted here)
  const recipientAddress = deployerWallet.address;

  // Token parameters
  const tokenName = "Test Bridge Token";
  const tokenSymbol = "TBT";
  const initialSupply = "1000000"; // 1 million tokens (will be multiplied by 10^18)

  console.log("\n=== Deploying Test ERC20 Token to Sepolia ===\n");

  // Read the TestToken artifact
  const artifactPath = "artifacts/contracts/TestToken.sol/TestToken.json";

  if (!fs.existsSync(artifactPath)) {
    console.log("❌ Contract artifact not found. Compiling contracts...");
    console.log("   Please run: npx hardhat compile");
    console.log("   Then run this script again.");
    return;
  }

  const { abi, bytecode } = JSON.parse(fs.readFileSync(artifactPath, "utf8"));

  console.log("Deploying TestToken contract to Sepolia...");
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
  console.log(`View on Etherscan: https://sepolia.etherscan.io/address/${contract.address}`);

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

  // Check balance
  const recipientBalance = await contract.balanceOf(recipientAddress);

  console.log(`\n=== Balances ===`);
  console.log(`Recipient (${recipientAddress}): ${ethers.utils.formatUnits(recipientBalance, decimals)} ${symbol}`);

  console.log(`\n=== Important Contract Addresses ===`);
  console.log(`Gravity Contract: 0xF271285B97b1fD14Ebb59274b5Aa1b4422526523`);
  console.log(`Test Token (TBT): ${contract.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
