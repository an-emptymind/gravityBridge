import { ethers } from "ethers";

async function main() {
  // Connect to your running node
  const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");

  // The Gravity contract address you're trying to use
  const contractAddress = "0xf784709d2317D872237C4bC22f867d1BAe2913AB";

  console.log("\n=== Verifying Gravity Contract ===\n");

  // Check network
  const network = await provider.getNetwork();
  console.log(`Network: ${network.name} (Chain ID: ${network.chainId})`);

  const blockNumber = await provider.getBlockNumber();
  console.log(`Current Block: ${blockNumber}\n`);

  console.log(`Checking contract at: ${contractAddress}\n`);

  // Check if there's code at the address
  const code = await provider.getCode(contractAddress);

  if (code === "0x" || code === "0x0") {
    console.log("❌ No contract found at this address!");
    console.log("The contract is not deployed on this chain.\n");
    console.log("You need to deploy the Gravity contract first.");
    console.log("\nTo deploy, you can use:");
    console.log("  cd solidity");
    console.log("  npx hardhat run contract-deployer.ts\n");
  } else {
    console.log("✓ Contract code found at this address!");
    console.log(`Code size: ${(code.length - 2) / 2} bytes\n`);

    // Try to get the deployment transaction
    console.log("Searching for deployment transaction...\n");

    // Search recent blocks for contract deployment
    const searchBlocks = Math.min(blockNumber, 1000); // Search last 1000 blocks or all blocks

    for (let i = Math.max(0, blockNumber - searchBlocks); i <= blockNumber; i++) {
      const block = await provider.getBlockWithTransactions(i);

      for (const tx of block.transactions) {
        if (tx.to === null) { // Contract creation
          const receipt = await provider.getTransactionReceipt(tx.hash);
          if (receipt.contractAddress) {
            console.log(`Found contract deployment at block ${i}:`);
            console.log(`  Contract Address: ${receipt.contractAddress}`);
            console.log(`  Transaction Hash: ${tx.hash}`);
            console.log(`  Deployer: ${tx.from}`);
            console.log(`  Gas Used: ${receipt.gasUsed.toString()}`);
            console.log("");
          }
        }
      }
    }
  }

  // Also check if the address has a balance
  const balance = await provider.getBalance(contractAddress);
  console.log(`Contract Balance: ${ethers.utils.formatEther(balance)} ETH`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
