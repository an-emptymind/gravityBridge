import { ethers } from "ethers";

async function main() {
  // Connect to your running node
  const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");

  // Account #0 private key (has ETH and deployed the contracts)
  const deployerPrivateKey = "0xc5e8f61d1ab959b397eecc0a37a6517b8e67a0e7cf1f4bce5591f3ed80199122";
  const deployerWallet = new ethers.Wallet(deployerPrivateKey, provider);

  // The ERC20 token address you want to mint/transfer
  const erc20Address = "0x7c2C195CD6D34B8F845992d380aADB2730bB9C6F";

  // The recipient address (your orchestrator's ETH address)
  const recipientAddress = "0x32cDc9954FF105339D4C9f96134E95fa66e619E8";

  // Amount to send (in tokens, will be converted to wei equivalent)
  const amountInTokens = "0.00000000000001"; // 5000 tokens (out of 10000 available)

  console.log("\n=== Minting/Sending Test ERC20 Tokens ===\n");

  // ERC20 ABI (minimal interface for transfer, mint and balanceOf)
  const erc20Abi = [
    "function transfer(address to, uint256 amount) returns (bool)",
    "function mint(address to, uint256 amount) returns (bool)",
    "function balanceOf(address owner) view returns (uint256)",
    "function decimals() view returns (uint8)",
    "function name() view returns (string)",
    "function symbol() view returns (string)",
  ];

  const erc20Contract = new ethers.Contract(erc20Address, erc20Abi, deployerWallet);

  try {
    // Get token info
    const name = await erc20Contract.name();
    const symbol = await erc20Contract.symbol();
    const decimals = await erc20Contract.decimals();

    console.log(`Token: ${name} (${symbol})`);
    console.log(`Decimals: ${decimals}`);
    console.log(`Token Address: ${erc20Address}`);

    // Check deployer balance
    const deployerBalance = await erc20Contract.balanceOf(deployerWallet.address);
    console.log(`\nDeployer (${deployerWallet.address}) balance: ${ethers.utils.formatUnits(deployerBalance, decimals)} ${symbol}`);

    // Check recipient balance before
    const recipientBalanceBefore = await erc20Contract.balanceOf(recipientAddress);
    console.log(`Recipient (${recipientAddress}) balance before: ${ethers.utils.formatUnits(recipientBalanceBefore, decimals)} ${symbol}`);

    if (deployerBalance.eq(0)) {
      console.log("\n❌ Deployer has no tokens! The test ERC20 might not have been minted properly.");
      console.log("Please check if the contracts were deployed with --test-mode=true");
      return;
    }

    // Transfer tokens
    const amountToSend = ethers.utils.parseUnits(amountInTokens, decimals);
    console.log(`\nTransferring ${amountInTokens} ${symbol} to ${recipientAddress}...`);

    const tx = await erc20Contract.transfer(recipientAddress, amountToSend);
    console.log(`Transaction hash: ${tx.hash}`);

    const receipt = await tx.wait();
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

    // Check recipient balance after
    const recipientBalanceAfter = await erc20Contract.balanceOf(recipientAddress);
    console.log(`\nRecipient balance after: ${ethers.utils.formatUnits(recipientBalanceAfter, decimals)} ${symbol}`);

    console.log("\n✅ Tokens transferred successfully!");
    console.log(`\nYou can now use this token address in eth-to-cosmos: ${erc20Address}`);
  } catch (error) {
    console.error("\n❌ Error:", (error as any).message);
    if ((error as any).reason) {
      console.error("Reason:", (error as any).reason);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
