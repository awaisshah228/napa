// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NapaReward.sol";


contract NAPA is ERC20,NapaReward {
    
    
    constructor(uint256 initialSupply) public ERC20("NAPA", "NAPA") {
        _mint(msg.sender, initialSupply);
        rewardTotal= totalSupply()*1/10;
    }
    

   
    function transfer(address to, uint256 amount) public  override returns (bool) {
        address owner = _msgSender();
        uint tax= amount*1/100;
        rewardTotal+=tax;
        amount-=tax;
        _transfer(owner, to, amount);
        return true;
    }
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public  override returns (bool) {
        address spender = _msgSender();
         uint tax= amount*2/100;
         rewardTotal+=tax;
         amount-=tax;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
}