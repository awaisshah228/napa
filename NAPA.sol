pragma solidity ^0.8.0;
// SPDX-License-Identifier: GPL

import "./ERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./NapaReward.sol";

contract NAPA is ERC20, Ownable {
    using SafeMath for uint256;

    // BUSD mainnet
    // address public BUSD = ;

    // TODO remove
    address public BUSD;

    // PancakeSwap
    IUniswapV2Router02 public uniswapRouter;
    address public uniswapPair;

    address public treasuryWallet;

    // addresses that are excluded from buying and selling fees
    mapping (address => bool) private isExcludedFromFees;

    // store addresses that are automatic market maker pairs
    mapping (address => bool) public automatedMarketMakerPairs;

    // events

    event UpdateUniSwapRouter(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event TreasuryWalletUpdated(address indexed newTreasuryWallet, address indexed oldTreasuryWallet);

    // constructor

    constructor() ERC20("NAPA Society", "NAPA") {
        // TODO change
        BUSD = 0x59f78fB97FB36adbaDCbB43Fa9031797faAad54A;

        IUniswapV2Router02 _uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        address _addressForPancakePair = IUniswapV2Factory(_uniswapRouter.factory()).getPair(address(this), BUSD);

        uniswapRouter = _uniswapRouter;
        uniswapPair = _addressForPancakePair;

        treasuryWallet = address(0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80);

        uint256 initialSupply = 1000000000 * (10 ** 18);

        _mint(owner(), initialSupply.mul(90).div(100));

        _mint(treasuryWallet, initialSupply.mul(10).div(100));
    }

    function updateUniSwapRouter(address newAddress) public onlyOwner {
        require(newAddress != address(uniswapRouter), "FRTNA: The router already has that address");
        emit UpdateUniSwapRouter(newAddress, address(uniswapRouter));
        uniswapRouter = IUniswapV2Router02(newAddress);
    }

     function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(isExcludedFromFees[account] != excluded, "FRTNA: Account is already the value of 'excluded'");
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
        require(pair != uniswapPair, "FRTNA: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(automatedMarketMakerPairs[pair] != value, "FRTNA: Automated market maker pair is already set to that value");
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
        return from != address(uniswapRouter) && automatedMarketMakerPairs[to];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (
            _isBuy(from) &&
            !isExcludedFromFees[to]
        ) {
            uint256 buyingFee = amount.mul(1).div(100);
            amount -= buyingFee;

            super._transfer(from, treasuryWallet, buyingFee);
        }

        if (
            _isSell(from, to) &&
            !isExcludedFromFees[from]
        ) {
            uint256 sellingFee = amount.mul(2).div(100);
            amount -= sellingFee;

            super._transfer(from, treasuryWallet, sellingFee);
        }

        super._transfer(from, to, amount);
    }
}