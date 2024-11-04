// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CarbonAllowanceManager.sol";

error CarbonTrader__NotEnoughDeposit();
error CarbonTrader__TradeNotExist();
error CarbonTrader__RefundFailed();
error CarbonTrader__ParamsError();
error CarbonTrader__FinalizeAuctionFailed();

contract CarbonAuctionTrade is CarbonAllowanceManager {
    event NewAuctionTrade(
        address indexed seller,
        uint256 amount,
        uint256 startTimeStamp,
        uint256 endTimeStamp,
        uint256 minimumBidAmount,
        uint256 initPriceOfUint
    );

    event Deposit(address indexed buyer, string tradeID, uint256 amount);

    event RefundDeposit(address indexed buyer, string tradeID, uint256 amount);

    event FinalizeAuctionAndTransferCarbon(
        address indexed buyer,
        string tradeID,
        uint256 allowanceAmount,
        uint256 additionalAmountToPay
    );

    event WithdrawAuctionAmount(address indexed user, uint256 amount);

    struct AuctionTrade {
        address seller;
        uint256 sellAmount;
        uint256 startTimeStamp;
        uint256 endTimeStamp;
        uint256 minimumBidAmount;
        uint256 initPriceOfUint;
        mapping(address => uint256) deposits;
        mapping(address => string) bidInfos;
        mapping(address => string) bidSecrets;
    }
    mapping(string => AuctionTrade) private s_auctionTrades;
    mapping(address => uint256) private s_auctionAmount;
    IERC20 private immutable i_usdtToken;
    constructor(address usdtTokenAddress) {
        i_usdtToken = IERC20(usdtTokenAddress);
    }

    function startAuctionTrade(
        string memory tradeID,
        uint256 amount,
        uint256 startTimeStamp,
        uint256 endTimeStamp,
        uint256 minimumBidAmount,
        uint256 initPriceOfUint
    ) public {
        if (
            amount <= 0 ||
            startTimeStamp >= endTimeStamp ||
            minimumBidAmount <= 0 ||
            initPriceOfUint <= 0 ||
            minimumBidAmount > amount
        ) revert CarbonTrader__ParamsError();
        AuctionTrade storage newTrade = s_auctionTrades[tradeID];
        newTrade.seller = msg.sender;
        newTrade.sellAmount = amount;
        newTrade.startTimeStamp = startTimeStamp;
        newTrade.endTimeStamp = endTimeStamp;
        newTrade.minimumBidAmount = minimumBidAmount;
        newTrade.initPriceOfUint = initPriceOfUint;

        s_addressToAllowances[msg.sender] -= amount;
        s_frozenAllowances[msg.sender] += amount;

        emit NewAuctionTrade(
            msg.sender,
            amount,
            startTimeStamp,
            endTimeStamp,
            minimumBidAmount,
            initPriceOfUint
        );
    }

    function getAuctionTrade(
        string memory tradeID
    )
        public
        view
        returns (address, uint256, uint256, uint256, uint256, uint256)
    {
        AuctionTrade storage currentTrade = s_auctionTrades[tradeID];
        return (
            currentTrade.seller,
            currentTrade.sellAmount,
            currentTrade.startTimeStamp,
            currentTrade.endTimeStamp,
            currentTrade.minimumBidAmount,
            currentTrade.initPriceOfUint
        );
    }

    function deposit(
        string memory tradeID,
        uint256 amount,
        string memory info
    ) public {
        AuctionTrade storage currentTrade = s_auctionTrades[tradeID];
        if (currentTrade.seller == address(0))
            revert CarbonTrader__TradeNotExist();
        if (amount < currentTrade.initPriceOfUint)
            revert CarbonTrader__NotEnoughDeposit();

        bool success = i_usdtToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) revert CarbonTrader__TransferFailed();

        currentTrade.deposits[msg.sender] = amount;
        emit Deposit(msg.sender, tradeID, amount);

        setBidInfo(tradeID, info);
    }

    function refundDeposit(string memory tradeID) public {
        AuctionTrade storage currentTrade = s_auctionTrades[tradeID];
        uint256 depositAmount = currentTrade.deposits[msg.sender];
        currentTrade.deposits[msg.sender] = 0;

        bool success = i_usdtToken.transfer(msg.sender, depositAmount);
        if (!success) {
            currentTrade.deposits[msg.sender] = depositAmount;
            revert CarbonTrader__TransferFailed();
        }
        emit RefundDeposit(msg.sender, tradeID, depositAmount);
    }

    function setBidInfo(string memory tradeID, string memory info) public {
        s_auctionTrades[tradeID].bidInfos[msg.sender] = info;
    }

    function setBidSecret(string memory tradeID, string memory secret) public {
        s_auctionTrades[tradeID].bidSecrets[msg.sender] = secret;
    }

    function getBidInfo(
        string memory tradeID
    ) public view returns (string memory) {
        return s_auctionTrades[tradeID].bidInfos[msg.sender];
    }

    function getBidSecret(
        string memory tradeID
    ) public view returns (string memory) {
        return s_auctionTrades[tradeID].bidSecrets[msg.sender];
    }

    function getTradeDeposit(
        string memory tradeID
    ) public view returns (uint256) {
        return s_auctionTrades[tradeID].deposits[msg.sender];
    }

    function getAuctionAmount() public view returns (uint256) {
        return s_auctionAmount[msg.sender];
    }

    function finalizeAuctionAndTransferCarbon(
        string memory tradeID,
        uint256 allowanceAmount,
        uint256 additionalAmountToPay
    ) public {
        // 获取保证金
        uint256 depositAmount = s_auctionTrades[tradeID].deposits[msg.sender];
        s_auctionTrades[tradeID].deposits[msg.sender] = 0;
        // 把保证金和追加金额单独记录给卖家
        address seller = s_auctionTrades[tradeID].seller;
        s_auctionAmount[seller] += (depositAmount + additionalAmountToPay);
        // 扣除卖家的冻结碳额度
        s_frozenAllowances[seller] -= allowanceAmount;
        // 增加买家的碳额度
        s_addressToAllowances[msg.sender] += allowanceAmount;

        bool success = i_usdtToken.transferFrom(
            msg.sender,
            address(this),
            additionalAmountToPay
        );
        if (!success) revert CarbonTrader__FinalizeAuctionFailed();
    }

    function withdrawAuctionAmount() public {
        uint256 auctionAmount = s_auctionAmount[msg.sender];
        s_auctionAmount[msg.sender] = 0;
        bool success = i_usdtToken.transfer(msg.sender, auctionAmount);
        if (!success) revert CarbonTrader__RefundFailed();
        emit WithdrawAuctionAmount(msg.sender, auctionAmount);
    }
}
