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

    // events

    event UpdateTreasuryWallet(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    // constructor

    constructor() ERC20("NAPA Society", "NAPA") {
        treasuryWallet = address(0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80);

        // exclude from paying fees
        excludeFromFees(address(this), true);
        excludeFromFees(owner(), true);
        excludeFromFees(treasuryWallet, true);

        // minting process
        uint256 initialSupply = 1000000000 * (10 ** 18);

        _mint(owner(), initialSupply.mul(90).div(100));

        _mint(treasuryWallet, initialSupply.mul(10).div(100));
    }

    function initializeUniswapRouter(address newUniswapRouter) public onlyOwner {
        require(uniswapRouter == address(0), "NAPA: UniSwapV3 Router has already been initialized");
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