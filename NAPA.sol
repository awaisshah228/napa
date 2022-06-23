// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NAPA is ERC20 {
    constructor(uint256 initialSupply) public ERC20("NAPA", "NAPA") {
        _mint(msg.sender, initialSupply);
    }
}