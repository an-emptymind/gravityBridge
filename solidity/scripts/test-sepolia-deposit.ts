import { ethers } from "ethers";
import fs from "fs";

/**
 * Test script for sending tokens from Sepolia to Gravity Bridge
 * This demonstrates the Sepolia → Gravity Bridge deposit flow
 */

async function main() {
  console.log("\n" + "=".repeat(60));
  console.log("Test: Sepolia → Gravity Bridge Deposit");
  console.log("=".repeat(60) + "\n");

  // Configuration
  const SEPOLIA_RPC = process.env.SEPOLIA_RPC || "https://ethereum-sepolia-rpc.publicnode.com";
  const SEPOLIA_PRIVATE_KEY = process.env.SEPOLIA_PRIVATE_KEY;
  const TOKEN_ADDRESS = process.env.TOKEN_ADDRESS;
  const GRAVITY_CONTRACT = process.env.GRAVITY_CONTRACT_ADDRESS;
  const DESTINATION = process.env.DESTINATION_COSMOS_ADDRESS;
  const AMOUNT = process.env.AMOUNT || "100"; // Default 100 tokens

  // Validate inputs
  if (!SEPOLIA_PRIVATE_KEY) {
    console.error("❌ Error: SEPOLIA_PRIVATE_KEY not set");
    console.error("\nUsage:");
    console.error("  export SEPOLIA_PRIVATE_KEY=0x...");
    console.error("  export TOKEN_ADDRESS=0x...");
    console.error("  export GRAVITY_CONTRACT_ADDRESS=0x...");
    console.error("  export DESTINATION_COSMOS_ADDRESS=gravity1...");
    console.error("  export AMOUNT=100  # Optional, defaults to 100");
    console.error("  npx ts-node scripts/test-sepolia-deposit.ts");
    process.exit(1);
  }

  if (!TOKEN_ADDRESS) {
    console.error("❌ Error: TOKEN_ADDRESS not set");
    console.error("Deploy a test token first: npx ts-node scripts/deploy-test-token-sepolia.ts");
    process.exit(1);
  }

  if (!GRAVITY_CONTRACT) {
    console.error("❌ Error: GRAVITY_CONTRACT_ADDRESS not set");
    console.error("Deploy Gravity contract first: npx ts-node deploy-sepolia-gravity-mainnet.ts");
    process.exit(1);
  }

  if (!DESTINATION) {
    console.error("❌ Error: DESTINATION_COSMOS_ADDRESS not set");
    console.error("This should be your Gravity Bridge address (gravity1...)");
    process.exit(1);
  }

  // Connect to Sepolia
  const provider = new ethers.providers.JsonRpcProvider(SEPOLIA_RPC);
  const wallet = new ethers.Wallet(SEPOLIA_PRIVATE_KEY, provider);

  console.log("Configuration:");
  console.log(`  Sender (Ethereum): ${wallet.address}`);
  console.log(`  Destination (Cosmos): ${DESTINATION}`);
  console.log(`  Token: ${TOKEN_ADDRESS}`);
  console.log(`  Gravity Contract: ${GRAVITY_CONTRACT}`);
  console.log(`  Amount: ${AMOUNT} tokens\n`);

  // Load token ABI
  const tokenArtifact = JSON.parse(
    fs.readFileSync("artifacts/contracts/TestToken.sol/TestToken.json", "utf8")
  );
  const token = new ethers.Contract(TOKEN_ADDRESS, tokenArtifact.abi, wallet);

  // Load Gravity contract ABI
  const gravityArtifact = JSON.parse(
    fs.readFileSync("artifacts/contracts/Gravity.sol/Gravity.json", "utf8")
  );
  const gravity = new ethers.Contract(GRAVITY_CONTRACT, gravityArtifact.abi, wallet);

  try {
    // Check token balance
    console.log("Checking token balance...");
    const balance = await token.balanceOf(wallet.address);
    const decimals = await token.decimals();
    const symbol = await token.symbol();

    const balanceFormatted = ethers.utils.formatUnits(balance, decimals);
    console.log(`  Balance: ${balanceFormatted} ${symbol}`);

    const amountWei = ethers.utils.parseUnits(AMOUNT, decimals);

    if (balance.lt(amountWei)) {
      console.error(`\n❌ Insufficient balance!`);
      console.error(`  Required: ${AMOUNT} ${symbol}`);
      console.error(`  Available: ${balanceFormatted} ${symbol}`);
      process.exit(1);
    }

    // Check allowance
    console.log("\nChecking token allowance...");
    const allowance = await token.allowance(wallet.address, GRAVITY_CONTRACT);
    const allowanceFormatted = ethers.utils.formatUnits(allowance, decimals);
    console.log(`  Current allowance: ${allowanceFormatted} ${symbol}`);

    if (allowance.lt(amountWei)) {
      console.log(`\n📝 Approving Gravity contract to spend ${AMOUNT} ${symbol}...`);
      const approveTx = await token.approve(GRAVITY_CONTRACT, amountWei);
      console.log(`  Transaction: ${approveTx.hash}`);
      console.log(`  Waiting for confirmation...`);
      await approveTx.wait();
      console.log(`  ✅ Approval confirmed`);
    } else {
      console.log(`  ✅ Already approved`);
    }

    // Send tokens to Cosmos
    console.log(`\n🌉 Sending ${AMOUNT} ${symbol} to Gravity Bridge...`);
    console.log(`  Calling sendToCosmos on Gravity contract...`);

    const sendTx = await gravity.sendToCosmos(
      TOKEN_ADDRESS,
      DESTINATION,
      amountWei
    );

    console.log(`  Transaction: ${sendTx.hash}`);
    console.log(`  Etherscan: https://sepolia.etherscan.io/tx/${sendTx.hash}`);
    console.log(`  Waiting for confirmation...`);

    const receipt = await sendTx.wait();

    console.log(`  ✅ Transaction confirmed in block ${receipt.blockNumber}`);

    // Parse events
    console.log(`\n📊 Transaction Events:`);
    for (const log of receipt.logs) {
      try {
        const parsed = gravity.interface.parseLog(log);
        if (parsed.name === "SendToCosmosEvent") {
          console.log(`\n  Event: SendToCosmosEvent`);
          console.log(`    Token: ${parsed.args._tokenContract}`);
          console.log(`    Sender: ${parsed.args._sender}`);
          console.log(`    Destination: ${parsed.args._destination}`);
          console.log(`    Amount: ${ethers.utils.formatUnits(parsed.args._amount, decimals)} ${symbol}`);
          console.log(`    Event Nonce: ${parsed.args._eventNonce}`);
        }
      } catch (e) {
        // Not a Gravity event, skip
      }
    }

    console.log("\n" + "=".repeat(60));
    console.log("✅ SUCCESS - Tokens Sent to Gravity Bridge");
    console.log("=".repeat(60));
    console.log("\nWhat happens next:");
    console.log("1. Sepolia block needs to be finalized (~13 minutes)");
    console.log("2. Orchestrator will detect the SendToCosmosEvent");
    console.log("3. Orchestrator submits claim to Gravity Bridge chain");
    console.log("4. Tokens will appear in your Cosmos address\n");

    console.log("Monitor orchestrator logs for:");
    console.log(`  [INFO] Oracle observed deposit with sender ${wallet.address.toLowerCase()}`);
    console.log("\nCheck your Cosmos balance:");
    console.log(`  gravity query bank balances ${DESTINATION} --node https://gravitychain.io:26657`);
    console.log("\nExpected denom:");
    console.log(`  gravity${TOKEN_ADDRESS.toLowerCase()}`);
    console.log("\n" + "=".repeat(60) + "\n");

  } catch (error: any) {
    console.error("\n❌ Transaction failed:");
    if (error.code === "INSUFFICIENT_FUNDS") {
      console.error("Insufficient Sepolia ETH for gas");
    } else if (error.reason) {
      console.error(error.reason);
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
