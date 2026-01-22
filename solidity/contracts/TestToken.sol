//SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.10;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Custom test token with large initial supply
contract TestToken is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        address recipient,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        // Mint initialSupply tokens (with 18 decimals) to recipient
        _mint(recipient, initialSupply * 10**18);
    }
}
