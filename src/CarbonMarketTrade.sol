// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CarbonAllowanceManager.sol";

contract CarbonMarketTrade is CarbonAllowanceManager {
    enum MarketTradeStatus {
        Trading,
        Cancel,
        End
    }

    struct MarketTrade {
        address seller;
        uint256 sellAmount;
        uint256 priceOfUint;
        MarketTradeStatus status;
        address buyer;
    }
    mapping(string => MarketTrade) private s_marketTrades;
    IERC20 private immutable i_usdtToken;
    constructor(address usdtTokenAddress) {
        i_usdtToken = IERC20(usdtTokenAddress);
    }
    function startMarketTrade(
        string memory tradeID,
        uint256 amount,
        uint256 priceOfUint
    ) public {
        // TODO 加一些前置校验，allowances数量之类的

        MarketTrade storage newTrade = s_marketTrades[tradeID];
        newTrade.seller = msg.sender;
        newTrade.sellAmount = amount;
        newTrade.priceOfUint = priceOfUint;
        newTrade.status = MarketTradeStatus.Trading;

        s_addressToAllowances[msg.sender] -= amount;
        s_frozenAllowances[msg.sender] += amount;

        // TODO 补一个事件
    }

    function updateMarketTrade(
        string memory tradeID,
        uint256 priceOfUint,
        MarketTradeStatus status
    ) public {
        // TODO 加个校验，只有交易的发起者才可以修改交易信息
        MarketTrade storage currentTrade = s_marketTrades[tradeID];
        currentTrade.priceOfUint = priceOfUint;
        currentTrade.status = status;

        // TODO 补个事件
    }

    function makeADeal(string memory tradeID) public {
        MarketTrade storage currentTrade = s_marketTrades[tradeID];
        uint256 sellAmount = currentTrade.sellAmount;
        uint256 totalPrice = currentTrade.sellAmount * currentTrade.priceOfUint;

        // TODO 加个校验，如果转过来的钱小于 amount * priceOfUint，就报错
        // 转钱给卖家
        bool success = i_usdtToken.transfer(currentTrade.seller, totalPrice);
        if (!success) {
            revert CarbonTrader__TransferFailed();
        }

        s_frozenAllowances[currentTrade.seller] -= sellAmount;
        s_addressToAllowances[msg.sender] += sellAmount;

        // TODO 补个事件
    }

    function getMarketTrade(
        string memory tradeID
    )
        public
        view
        returns (address, uint256, uint256, MarketTradeStatus, address)
    {
        MarketTrade storage currentTrade = s_marketTrades[tradeID];
        return (
            currentTrade.seller,
            currentTrade.sellAmount,
            currentTrade.priceOfUint,
            currentTrade.status,
            currentTrade.buyer
        );
    }
}
