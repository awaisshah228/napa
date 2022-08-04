pragma solidity ^0.8.0;
// SPDX-License-Identifier: GPL

import "./ERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract NAPA is ERC20, Ownable {
    using SafeMath for uint256;

    // uniswapV3 router address
    address public uniswapRouter;

    // treasury wallet
    address public treasuryWallet;

    // addresses that are excluded from buying and selling fees
    mapping (address => bool) private isExcludedFromFees;

    // store addresses that are automatic market maker pairs
    mapping (address => bool) public automatedMarketMakerPairs;

    // buy & sell fee
    uint256 internal buyFee;
    uint256 internal sellFee;
    
    // buy & sell limits
    uint256 public buyLimit;
    uint256 public sellLimit;

    // time lock
    bool public timeLimit = false;

    uint private timeLock = 86400;

    // pause trading
    bool public paused = true;

    mapping (address => uint256) _sellTime;
    mapping (address => uint256) _buyTime;

    // black listed address
    mapping(address => bool) public _isBlacklisted;

    struct Limiter {
        address walletAddress;
        uint256 limitStartTime;
    }

    mapping (address => Limiter) private _limitedUsers;

    // events

    event UpdateTreasuryWallet(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event Blacklisted(address account);

    // constructor

    constructor() ERC20("NAPA Society", "NAPA") {
        buyFee = 1;
        sellFee = 2;

        treasuryWallet = address(0x2BC68c7D1a1DfFFE08F02e3eF3c7ED8d322B9CfB);
        address owner_ = address(0xC3330271fC4465f2481476AD96FcF635F07Aa2Dc);

        // exclude from paying fees
        excludeFromFees(address(this), true);
        excludeFromFees(owner_, true);
        excludeFromFees(treasuryWallet, true);

        // minting
        uint256 initialSupply = 1000000000 * (10 ** 18);

        _mint(owner_, initialSupply.mul(90).div(100));

        _mint(treasuryWallet, initialSupply.mul(10).div(100));

        transferOwnership(owner_);
    }

    function updateUniswapRouter(address newUniswapRouter) public onlyOwner {
        uniswapRouter = newUniswapRouter;
    }

    function updateTreasuryWallet(address newAddress) public onlyOwner {
        require(newAddress != treasuryWallet, "NAPA: The treasury wallet already has that address");
        emit UpdateTreasuryWallet(newAddress, treasuryWallet);
        treasuryWallet = newAddress;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(isExcludedFromFees[account] != excluded, "NAPA: Account is already the value of 'excluded'");
        isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(automatedMarketMakerPairs[pair] != value, "NAPA: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    // functions

    function _isBuy(address from) internal view returns (bool) {
        // Transfer from pair is a buy swap
        return automatedMarketMakerPairs[from];
    }

    function _isSell(address from, address to) internal view returns (bool) {
        // Transfer to pair from non-router address is a sell swap
        return from != uniswapRouter && automatedMarketMakerPairs[to];
    }

    function circulatingSupply() public view returns (uint256) {
        return totalSupply().sub(balanceOf(owner()));
    }

    /* ========== FUNCTIONS FOR SELLING LIMIT ========== */

    function handleLimit(address from) internal {
        if (isLimitedUser(from)) {
            if (block.timestamp > _limitedUsers[from].limitStartTime.add(timeLock)) {
                removeLimitedUser(from);
            }
            else {
                revert("NAPA: Currently blocked from selling. Please try again after ~24 hours");
            }
        }
    }

    // adds to limited users whenever a user receives tokens
    function addLimitedUser(address to) internal {
        _limitedUsers[to] = Limiter(to, block.timestamp);
    }

    // checks if limited user only when selling
    function isLimitedUser(address from) internal view returns (bool) {
        return _limitedUsers[from].walletAddress == from;
    }

    // removes from limited users only when selling
    function removeLimitedUser(address from) internal {
        Limiter memory emptyLimiter;
        _limitedUsers[from] = emptyLimiter;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(!paused, "Trading is paused");
        require(from != to, "Sending to yourself is disallowed");
        require(!_isBlacklisted[from] && !_isBlacklisted[to],    "Blacklisted account");
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (!isExcludedFromFees[to]) {
            addLimitedUser(to);
        }

        // stopping users from selling if they have received tokens in the previous 24 hours
        if (_isSell(from, to) && !isExcludedFromFees[from]) {
            handleLimit(from);
        }

        // indicates if fee should be deducted from transfer
        bool takeFee = true;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(isExcludedFromFees[from] || isExcludedFromFees[to]){
            takeFee = false;
        }

        _validateTransfer(from, to, amount, takeFee);

        if(timeLimit){
            _validateTime(from , to , takeFee);
        }

        if (_isBuy(from) && !isExcludedFromFees[to]) {
            uint256 buyingFee = amount.mul(buyFee).div(100);

            amount -= buyingFee;

            super._transfer(from, treasuryWallet, buyingFee);
        }

        if (_isSell(from, to) && !isExcludedFromFees[from]) {
            uint256 sellingFee = amount.mul(sellFee).div(100);

            amount -= sellingFee;

            super._transfer(from, treasuryWallet, sellingFee);
        }

        super._transfer(from, to, amount);
    }

    function _validateTransfer(address sender,address recipient,uint256 amount,bool takeFee ) private view {
        // Excluded addresses don't have limits
        if (takeFee) {
            if (_isBuy(sender) && buyLimit != 0) {
                require(amount <= buyLimit, "Buy amount exceeds limit");
            } else if (_isSell(sender, recipient) && sellLimit != 0) {
                require(amount <= sellLimit, "Sell amount exceeds limit");
            }
        }
    }

    function _validateTime(address sender, address recipient, bool takeFee) private {   
         // Excluded addresses don't have time limits
        if (takeFee) {
            if (_isBuy(sender)) {
                require(_buyTime[recipient] + 4 minutes <= block.timestamp, "wait 4 minutes to buy again");
                _buyTime[recipient] = block.timestamp;
            } else if (_isSell(sender, recipient)) {
                require(_sellTime[sender] + 5 minutes <= block.timestamp, "wait 5 minutes to sell again");
                _sellTime[sender] = block.timestamp;
            }
        }
    }

    function updateBuyLimit(uint256 limit) external onlyOwner {
        buyLimit = limit;
    }

    function updateSellLimit(uint256 limit) external onlyOwner {
        sellLimit = limit;
    }

    function addToBlacklist(address account) external onlyOwner {
        _isBlacklisted[account] = true;
        emit Blacklisted(account);
    }

    function removeFromBlacklist(address account) external onlyOwner {
        _isBlacklisted[account] = false;
    }

    function _isExcludedFromFee(address account) public view returns(bool) {
        return isExcludedFromFees[account];
    }

    function updateBuyFee(uint256 _fee) external onlyOwner {
        buyFee = _fee;
    }

    function updateSellFee(uint256 _fee) external onlyOwner {
        sellFee = _fee;
    }

    function updateTimeLock(uint256 _time) external onlyOwner {
        timeLock = _time;
    }
}