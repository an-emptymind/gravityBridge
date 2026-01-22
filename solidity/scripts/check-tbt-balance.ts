import { ethers } from "ethers";

async function main() {
  const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");

  const address = "0x32cDc9954FF105339D4C9f96134E95fa66e619E8";
  const tokenAddress = "0xc4905364b78a742ccce7B890A89514061E47068D";

  const erc20Abi = [
    "function balanceOf(address) view returns (uint256)",
    "function decimals() view returns (uint8)",
    "function symbol() view returns (string)",
    "function name() view returns (string)"
  ];

  const contract = new ethers.Contract(tokenAddress, erc20Abi, provider);

  const balance = await contract.balanceOf(address);
  const decimals = await contract.decimals();
  const symbol = await contract.symbol();
  const name = await contract.name();

  console.log("\n=== Token Balance ===");
  console.log(`Token: ${name} (${symbol})`);
  console.log(`Address: ${address}`);
  console.log(`Balance: ${ethers.utils.formatUnits(balance, decimals)} ${symbol}`);
  console.log(`Raw Balance: ${balance.toString()}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
