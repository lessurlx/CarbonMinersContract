// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CarbonAllowanceManager.sol";

error AuctionTrade__ParamsError(
    uint256 amount,
    uint256 startTimeStamp,
    uint256 endTimeStamp,
    uint256 minimumBidAmount,
    uint256 initPriceOfUint
);
error AuctionTrade__TradeNotExist(uint256 tradeID);
error AuctionTrade__NotEnoughDeposit(uint256 needed, uint256 amount);
error AuctionTrade__UploadMsgMismatch(uint256 bidderLength, uint256 amountLength);
error AuctionTrade_NotBidWinner(uint256 tradeID, address operator);
error AuctionTrade_NotDeposit(uint256 tradeID, address operator);

contract CarbonAuctionTrade is CarbonAllowanceManager {
    event NewAuctionTrade(
        address indexed seller,
        uint256 amount,
        uint256 startTimeStamp,
        uint256 endTimeStamp,
        uint256 minimumBidAmount,
        uint256 initPriceOfUint
    );

    event Deposit(address indexed buyer, uint256 tradeID, uint256 amount);

    event RefundDeposit(address indexed buyer, uint256 tradeID, uint256 amount);

    event FinalizeAuctionAndTransferCarbon(
        address indexed buyer,
        uint256 tradeID,
        uint256 allowanceAmount,
        uint256 additionalAmountToPay
    );

    event WithdrawAuctionAmount(address indexed user, uint256 amount);

    struct AuctionTrade {
        address seller;
        uint256 amount;
        uint256 startTimeStamp;
        uint256 endTimeStamp;
        uint256 minimumBidAmount;
        uint256 initPriceOfUint;
        mapping(address => uint256) deposits;
        mapping(address => string) bidInfos;
        mapping(address => string) bidSecrets;
        mapping(address => uint256) bidWinner;
    }
    mapping(uint256 => AuctionTrade) public auctionTrades;
    mapping(address => uint256) public auctionAmount;
    IERC20 private immutable i_usdtToken;
    constructor(address usdtTokenAddress) {
        i_usdtToken = IERC20(usdtTokenAddress);
    }

    // 创建拍卖交易
    function startAuctionTrade(
        uint256 tradeID,
        uint256 amount,
        uint256 startTimeStamp,
        uint256 endTimeStamp,
        uint256 minimumBidAmount,
        uint256 initPriceOfUint
    ) public {
        // 检查参数
        if (
            amount <= 0 ||
            startTimeStamp >= endTimeStamp ||
            minimumBidAmount <= 0 ||
            initPriceOfUint <= 0 ||
            minimumBidAmount > amount
        ) revert AuctionTrade__ParamsError(amount, startTimeStamp, endTimeStamp, minimumBidAmount, initPriceOfUint);
        
        // 构造AuctionTrade
        AuctionTrade storage newTrade = auctionTrades[tradeID];
        newTrade.seller = msg.sender;
        newTrade.amount = amount;
        newTrade.startTimeStamp = startTimeStamp;
        newTrade.endTimeStamp = endTimeStamp;
        newTrade.minimumBidAmount = minimumBidAmount;
        newTrade.initPriceOfUint = initPriceOfUint;

        // 更新数据
        addressToAllowances[msg.sender] -= amount;
        frozenAllowances[msg.sender] += amount;

        emit NewAuctionTrade(
            msg.sender,
            amount,
            startTimeStamp,
            endTimeStamp,
            minimumBidAmount,
            initPriceOfUint
        );
    }

    // 存款用于竞标
    function deposit(
        uint256 tradeID,
        uint256 amount,
        string memory info
    ) public {
        AuctionTrade storage currentTrade = auctionTrades[tradeID];
        if (currentTrade.seller == address(0))
            revert AuctionTrade__TradeNotExist(tradeID);
        if (amount < currentTrade.initPriceOfUint)
            revert AuctionTrade__NotEnoughDeposit(currentTrade.initPriceOfUint, amount);

        bool success = i_usdtToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) revert ERC20__TransferFailed(msg.sender, address(this), amount);

        currentTrade.deposits[msg.sender] = amount;
        emit Deposit(msg.sender, tradeID, amount);

        setBidInfo(tradeID, info);
    }

    // 退回竞标时存入的钱
    function refundDeposit(uint256 tradeID) public {
        AuctionTrade storage currentTrade = auctionTrades[tradeID];
        if (currentTrade.seller == address(0)) revert AuctionTrade__TradeNotExist(tradeID);
        if(currentTrade.deposits[msg.sender] == 0) revert AuctionTrade_NotDeposit(tradeID, msg.sender);

        uint256 depositAmount = currentTrade.deposits[msg.sender];
        currentTrade.deposits[msg.sender] = 0;

        bool success = i_usdtToken.transfer(msg.sender, depositAmount);
        if (!success) {
            revert ERC20__TransferFailed(address(this), msg.sender, depositAmount);
        }
        emit RefundDeposit(msg.sender, tradeID, depositAmount);
    }

    // 设置竞标信息（密文形式）
    function setBidInfo(uint256 tradeID, string memory info) public {
        auctionTrades[tradeID].bidInfos[msg.sender] = info;
    }

    // 设置密码
    function setBidSecret(uint256 tradeID, string memory secret) public {
        auctionTrades[tradeID].bidSecrets[msg.sender] = secret;
    }

    // 获取竞标信息
    function getBidInfo(uint256 tradeID) public view returns (string memory) {
        return auctionTrades[tradeID].bidInfos[msg.sender];
    }

    // 获取密码
    function getBidSecret(uint256 tradeID) public view returns (string memory) {
        return auctionTrades[tradeID].bidSecrets[msg.sender];
    }

    // 获取存款
    function getTradeDeposit(uint256 tradeID) public view returns (uint256) {
        return auctionTrades[tradeID].deposits[msg.sender];
    }

    // 上传中标者数据
    function uploadBidWinner(
        uint256 tradeID, 
        address[] memory bidder, 
        uint256[] memory amount
    ) public onlyOwner {
        if(bidder.length != amount.length) revert AuctionTrade__UploadMsgMismatch(bidder.length, amount.length);
        AuctionTrade storage currentTrade = auctionTrades[tradeID];
        if (currentTrade.seller == address(0)) revert AuctionTrade__TradeNotExist(tradeID);

        // 遍历数组并存储数据
        for(uint i = 0; i < bidder.length; i++) {
            currentTrade.bidWinner[bidder[i]] = amount[i];
        }
    }

    function finalizeAuctionAndTransferCarbon(
        uint256 tradeID,
        uint256 allowanceAmount,
        uint256 additionalAmountToPay
    ) public {
        AuctionTrade storage currentTrade = auctionTrades[tradeID];
        if (currentTrade.seller == address(0)) revert AuctionTrade__TradeNotExist(tradeID);
        // 检查是否中标
        if(currentTrade.bidWinner[msg.sender] == 0) revert AuctionTrade_NotBidWinner(tradeID, msg.sender);
        // 获取保证金
        uint256 depositAmount = auctionTrades[tradeID].deposits[msg.sender];
        auctionTrades[tradeID].deposits[msg.sender] = 0;
        // 把保证金和追加金额单独记录给卖家
        address seller = auctionTrades[tradeID].seller;
        auctionAmount[seller] += (depositAmount + additionalAmountToPay);
        // 扣除卖家的冻结碳额度
        frozenAllowances[seller] -= allowanceAmount;
        // 增加买家的碳额度
        addressToAllowances[msg.sender] += allowanceAmount;

        bool success = i_usdtToken.transferFrom(
            msg.sender,
            address(this),
            additionalAmountToPay
        );
        if (!success) revert ERC20__TransferFailed(msg.sender, address(this), additionalAmountToPay);

        emit FinalizeAuctionAndTransferCarbon(
            msg.sender,
            tradeID,
            allowanceAmount,
            additionalAmountToPay
        );
    }

    function withdrawAuctionAmount() public {
        uint256 amount = auctionAmount[msg.sender];
        auctionAmount[msg.sender] = 0;
        bool success = i_usdtToken.transfer(msg.sender, amount);
        if (!success) revert ERC20__TransferFailed(address(this), msg.sender, amount);
        emit WithdrawAuctionAmount(msg.sender, amount);
    }
}
