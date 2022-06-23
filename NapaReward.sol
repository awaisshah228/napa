// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract NapaReward {
    uint rewardTotal;

 function updateReward(uint _reward) internal  returns(bool){
        require(rewardTotal>0, "reward empty");
        rewardTotal-=_reward;
        return true;
    }
 function getToatalReward() public view returns(uint){
     return rewardTotal;
 }
}