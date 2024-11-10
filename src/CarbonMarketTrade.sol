// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CarbonAllowanceManager.sol";

// 操作者与所属卖家不符
error MarketTrade__NotSeller(address seller, address operator);
// 该市场交易已结束
error MarketTrade__NotTrading(uint256 tradeID);
error MarketTrade__TradeNotExist(uint256 tradeID);

contract CarbonMarketTrade is CarbonAllowanceManager {
    // 新的市场交易事件
    event NewMarketTrade(address indexed seller, uint256 amount, uint256 priceOfUint);
    // 市场交易变更事件
    event UpdateMarketTrade(
        address indexed seller, 
        uint256 amount, 
        uint256 oldAmount, 
        uint256 priceOfUint, 
        uint256 oldPriceOfUint
    );
    // 交易成交事件
    event MakeADeal(address seller, address buyer, uint256 amount, uint256 priceOfUint);
    // 交易取消事件
    event CancelMarketTrade(uint256 tradeID);

    enum MarketTradeStatus {
        Trading,
        Cancel,
        End
    }

    struct MarketTrade {
        address seller;
        uint256 amount;
        uint256 priceOfUint;
        MarketTradeStatus status;
        address buyer;
    }

    mapping(uint256 => MarketTrade) public marketTrades;
    IERC20 private immutable i_usdtToken;  // 待调整！

    constructor(address usdtTokenAddress) {
        i_usdtToken = IERC20(usdtTokenAddress);
    }

    // 交易创建
    function createMarketTrade(
        uint256 tradeID,
        uint256 amount,
        uint256 priceOfUint
    ) public {
        // 检查碳排放额余额是否满足
        if(addressToAllowances[msg.sender] <= amount) {
            revert CarbonManager__AllowanceNotEnough(msg.sender, addressToAllowances[msg.sender], amount);
        }

        // 构造MarketTrade
        MarketTrade storage newTrade = marketTrades[tradeID];
        newTrade.seller = msg.sender;
        newTrade.amount = amount;
        newTrade.priceOfUint = priceOfUint;
        newTrade.status = MarketTradeStatus.Trading;

        // 更新碳排放额余额和冻结数量
        addressToAllowances[msg.sender] -= amount;
        frozenAllowances[msg.sender] += amount;

        emit NewMarketTrade(msg.sender, amount, priceOfUint);
    }

    // 修改MarketTrade
    function updateMarketTrade(
        uint256 tradeID,
        uint256 amount,
        uint256 priceOfUint
    ) public {
        MarketTrade storage trade = marketTrades[tradeID];
        if (trade.seller == address(0)) revert MarketTrade__TradeNotExist(tradeID);
        // 检查是否为所属卖家
        if(msg.sender != trade.seller) revert MarketTrade__NotSeller(trade.seller, msg.sender);
        // 检查是否为交易状态
        if(trade.status != MarketTradeStatus.Trading) revert MarketTrade__NotTrading(tradeID);

        // 修改价格
        uint256 oldPriceOfUint = trade.priceOfUint;  // 给事件提供数据
        trade.priceOfUint = priceOfUint;

        // 修改数量
        uint256 oldAmount = trade.amount;
        if(amount > oldAmount) {
            uint256 neededAmount = amount - oldAmount;
            if(addressToAllowances[msg.sender] <= neededAmount) {
                revert CarbonManager__AllowanceNotEnough(msg.sender, addressToAllowances[msg.sender], neededAmount);
            }
            addressToAllowances[msg.sender] -= neededAmount;
            frozenAllowances[msg.sender] += neededAmount;
        } else if(amount < oldAmount) {
            addressToAllowances[msg.sender] += (oldAmount - amount);
            frozenAllowances[msg.sender] -= (oldAmount - amount);
        }

        emit UpdateMarketTrade(msg.sender, amount, oldAmount, priceOfUint, oldPriceOfUint);
    }

    // 购买
    function makeADeal(uint256 tradeID) public {
        MarketTrade storage trade = marketTrades[tradeID];
        if (trade.seller == address(0)) revert MarketTrade__TradeNotExist(tradeID);
        // 检查是否为交易状态
        if(trade.status != MarketTradeStatus.Trading) revert MarketTrade__NotTrading(tradeID);

        uint256 totalPrice = trade.amount * trade.priceOfUint;

        bool success = i_usdtToken.transferFrom(msg.sender, trade.seller, totalPrice);
        if (!success) {
            revert ERC20__TransferFailed(msg.sender, trade.seller, totalPrice);
        }

        // 更新数据
        frozenAllowances[trade.seller] -= trade.amount;
        addressToAllowances[msg.sender] += trade.amount;
        trade.status = MarketTradeStatus.End;

        emit MakeADeal(trade.seller, msg.sender, trade.amount, trade.priceOfUint);
    }

    // 取消交易
    function cancelMarketTrade(uint256 tradeID) public {
        MarketTrade storage trade = marketTrades[tradeID];
        if (trade.seller == address(0)) revert MarketTrade__TradeNotExist(tradeID);
        // 检查是否为所属卖家
        if(msg.sender != trade.seller) revert MarketTrade__NotSeller(trade.seller, msg.sender);
        // 检查是否为交易状态
        if(trade.status != MarketTradeStatus.Trading) revert MarketTrade__NotTrading(tradeID);

        // 更新数据
        addressToAllowances[msg.sender] += trade.amount;
        frozenAllowances[msg.sender] -= trade.amount;
        trade.status = MarketTradeStatus.Cancel;

        emit CancelMarketTrade(tradeID);
    }
}
