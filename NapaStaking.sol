// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./NAPA.sol";
import "./NapaReward.sol";


contract NapaStaking  is Context, Ownable,NapaReward{

    NAPA immutable private token;
    uint256 public totalStaked;
    // mapping(uint=>uint) public packages;
  
   uint[4] packages;
   mapping(uint=>bool)plan;

   // user structer
    struct User {
        uint256 plan;
        uint256 amount;
        uint startTime;
        uint endTime;
    }
    // total deposited
    mapping(address => User) public deposit;

    //Events
    event Stake(address indexed staker, uint256 _amount, uint256 _lockPeriod );
    event Unstake(address indexed unstaker, uint256 unstakeTime);
    event Claim(address staker, uint256 reward);


    constructor(address token_) public {
        require(token_ != address(0x0));
        token = NAPA(token_);
        packages[0]=30;
        packages[1]=60;
        packages[2]=90;
        packages[3]=120;
        plan[30]=true;
        plan[60]=true;
        plan[90]=true;
        plan[120]=true;

    }
    // function getBalance() public view returns(uint){
    //     return token.totalSupply();
    // }

      function stakeTokens(uint256 _amount, uint256 _plan) public {
        require(token.balanceOf(_msgSender())>=_amount, "you do not have sufficient balance");
        require(token.allowance(_msgSender(), address(this))>=_amount, "Tokens not approved");
        require(plan[_plan], "select correct tier");
        User memory wUser = deposit[_msgSender()];
        require(wUser.amount == 0, "Already Staked");
        
        deposit[_msgSender()] = User(_plan, _amount,block.timestamp,block.timestamp+(_plan* 1 days));
        token.transferFrom(_msgSender(),address(this),_amount);
        totalStaked+=_amount;
        emit Stake(_msgSender(), _amount,_plan);
    }

    function UnstakeTokens() public {
        User memory wUser = deposit[_msgSender()];

        require(wUser.amount > 0, "deposit first");
        require(block.timestamp > wUser.startTime && block.timestamp<wUser.endTime, "Token locked");
        uint reward=_claim();
        rewardTotal-=reward;
        require(rewardTotal>0,"not suffiecint rewards available");
        token.transfer(_msgSender(),wUser.amount+reward);

        deposit[_msgSender()] = User(0, 0 , 0, 0);
        totalStaked-=wUser.amount;

        emit Unstake(_msgSender(), block.timestamp);
    }
     function _claim()  internal  returns (uint) {
        User storage info = deposit[_msgSender()];
        require(info.amount > 0, "Not Staked");
         uint _reward;
        // ufixed reward =(packages[info.plan]/100)*(info.amount);
        // return reward;
        
        if(info.plan == 30){
                    _reward = 10* info.amount/100;
        } else if(info.plan == 60){
                     _reward = 1279* info.amount/10000;
        } else if(info.plan == 90){
                    _reward = 1729* info.amount/10000;
        } else if(info.plan== 120){
                     _reward = 2218 * info.amount/10000;
        }
        if(_reward<10**12){
            _reward=10**12;
        }
        
        
        emit Claim(_msgSender() , _reward); 
        return _reward;
     

   
        
    }

    // function claim() public {
    //     _claim();
    // }


}