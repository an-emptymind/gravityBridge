import { ethers } from "hardhat";

async function main() {
  // Account #0 with the private key
  const fromPrivateKey = "0xc5e8f61d1ab959b397eecc0a37a6517b8e67a0e7cf1f4bce5591f3ed80199122";
  const fromAddress = "0xc783df8a850f42e7f7e57013759c285caa701eb6";

  // Destination account
  const toAddress = "0x32cDc9954FF105339D4C9f96134E95fa66e619E8";

  // Amount to transfer (in ETH)
  const amountInEth = "10000000"; // Change this to the amount you want to transfer

  // Create wallet from private key
  const wallet = new ethers.Wallet(fromPrivateKey, ethers.provider);

  console.log(`\nTransfer Details:`);
  console.log(`From: ${fromAddress}`);
  console.log(`To: ${toAddress}`);
  console.log(`Amount: ${amountInEth} ETH`);

  // Check balance before transfer
  const balanceBefore = await ethers.provider.getBalance(fromAddress);
  const balanceBeforeTo = await ethers.provider.getBalance(toAddress);

  console.log(`\nBalance Before Transfer:`);
  console.log(`From: ${ethers.utils.formatEther(balanceBefore)} ETH`);
  console.log(`To: ${ethers.utils.formatEther(balanceBeforeTo)} ETH`);

  // Create transaction
  const tx = {
    to: toAddress,
    value: ethers.utils.parseEther(amountInEth)
  };

  console.log(`\nSending transaction...`);
  const transaction = await wallet.sendTransaction(tx);
  console.log(`Transaction hash: ${transaction.hash}`);

  // Wait for confirmation
  console.log(`Waiting for confirmation...`);
  const receipt = await transaction.wait();
  console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

  // Check balance after transfer
  const balanceAfter = await ethers.provider.getBalance(fromAddress);
  const balanceAfterTo = await ethers.provider.getBalance(toAddress);

  console.log(`\nBalance After Transfer:`);
  console.log(`From: ${ethers.utils.formatEther(balanceAfter)} ETH`);
  console.log(`To: ${ethers.utils.formatEther(balanceAfterTo)} ETH`);

  console.log(`\nTransfer completed successfully!`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
