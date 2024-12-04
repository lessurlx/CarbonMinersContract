// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./CarbonAuctionTrade.sol";
import "./CarbonMarketTrade.sol";

contract CarbonTrader is CarbonAuctionTrade, CarbonMarketTrade {
    constructor(
        address usdtTokenAddress
    )
        CarbonAuctionTrade(usdtTokenAddress)
        CarbonMarketTrade(usdtTokenAddress)
    {}
}
