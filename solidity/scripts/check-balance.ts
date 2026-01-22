import { ethers } from "hardhat";

async function main() {
  // Add addresses you want to check here
  const addresses = [
    "0xc783df8a850f42e7f7e57013759c285caa701eb6", // Account #0
    "0x32cDc9954FF105339D4C9f96134E95fa66e619E8", // Destination account
  ];

  console.log("\n=== Checking Balances ===\n");

  for (const address of addresses) {
    try {
      const balance = await ethers.provider.getBalance(address);
      const balanceInEth = ethers.utils.formatEther(balance);

      console.log(`Address: ${address}`);
      console.log(`Balance: ${balanceInEth} ETH`);
      console.log(`Balance (wei): ${balance.toString()}`);
      console.log("---");
    } catch (error) {
      console.error(`Error checking balance for ${address}:`, error);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
