// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {CarbonTrader} from "../src/CarbonTrader.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract CarbonTraderTest is Test {
    CarbonTrader carbonTrader;
    ERC20Mock usdtToken;

    address owner = address(this); // The contract deployer
    address user1 = address(0x1); // Simulating a user
    address user2 = address(0x2); // Simulating another user

    function setUp() public {
        // 1_000_000 USDT, assuming USDT has 6 decimals
        uint256 initialSupply = 1_000_000 * 10 ** 6;
        usdtToken = new ERC20Mock("Mock USDT", "USDT", owner, initialSupply);
        carbonTrader = new CarbonTrader(address(usdtToken));
    }

    function testIssueAllowance() public {
        carbonTrader.issueAllowance(user1, 1000);
        assertEq(carbonTrader.getAllownance(user1), 1000);
    }

    function testFreezeAllowance() public {
        carbonTrader.issueAllowance(user1, 1000);
        carbonTrader.freezeAllowance(user1, 500);
        assertEq(carbonTrader.getAllownance(user1), 500);
        assertEq(carbonTrader.getFrozenAllowance(user1), 500);
    }

    function testUnfreezeAllowance() public {
        carbonTrader.issueAllowance(user1, 1000);
        carbonTrader.freezeAllowance(user1, 500);
        carbonTrader.unfreezeAllowance(user1, 500);
        assertEq(carbonTrader.getAllownance(user1), 1000);
        assertEq(carbonTrader.getFrozenAllowance(user1), 0);
    }

    function testDestoryAllowance() public {
        carbonTrader.issueAllowance(user1, 1000);
        carbonTrader.destoryAllowance(user1, 500);
        assertEq(carbonTrader.getAllownance(user1), 500);
    }

    function testStartTrade() public {
        string memory tradeID = "trade1";
        carbonTrader.issueAllowance(owner, 1000);
        carbonTrader.startTrade(
            tradeID,
            1000,
            block.timestamp,
            block.timestamp + 1 weeks,
            100,
            1 * 10 ** 6
        );
        (address seller, uint256 sellAmount, , , , ) = carbonTrader.getTrade(
            tradeID
        );
        assertEq(seller, owner);
        assertEq(sellAmount, 1000);
    }

    function testDeposit() public {
        string memory tradeID = "trade1";
        vm.prank(owner);
        carbonTrader.issueAllowance(user1, 1000);
        vm.prank(user1);
        carbonTrader.startTrade(
            tradeID,
            1000,
            block.timestamp,
            block.timestamp + 1 weeks,
            100,
            1 * 10 ** 6
        );

        usdtToken.mint(user2, 1 * 10 ** 6); // 为 user2 铸造 1 USDT
        vm.prank(user2); // 模拟 user2 调用合约
        usdtToken.approve(address(carbonTrader), 1 * 10 ** 6); // 授权 CarbonTrader 合约支配 user2 的 1 USDT

        vm.prank(user2);
        carbonTrader.deposit(tradeID, 1 * 10 ** 6, ""); // user2 存入 1 USDT
        vm.prank(user2);
        assertEq(carbonTrader.getTradeDeposit(tradeID), 1 * 10 ** 6); // 检查存款是否正确
    }

    function testRefundDeposit() public {
        string memory tradeID = "trade1";
        carbonTrader.issueAllowance(owner, 1000);
        carbonTrader.startTrade(
            tradeID,
            1000,
            block.timestamp,
            block.timestamp + 1 weeks,
            100,
            1 * 10 ** 6
        );

        usdtToken.mint(user1, 1 * 10 ** 6); // 为 user1 铸造 1 USDT
        vm.prank(user1); // 模拟 user1 调用合约

        // 检查user1的初始余额
        uint256 initialBalance = usdtToken.balanceOf(user1);

        vm.prank(user1); // 确保 approve 在 user1 上下文中运行
        usdtToken.approve(address(carbonTrader), 1 * 10 ** 6); // 授权 CarbonTrader 合约支配 user1 的 1 USDT

        vm.prank(user1); // 确保下一个调用在 user1 上下文中执行
        carbonTrader.deposit(tradeID, 1 * 10 ** 6, ""); // user1 存入 1 USDT
        assertEq(usdtToken.balanceOf(user1), initialBalance - 1 * 10 ** 6); // user1 应该扣除保证金
        assertEq(usdtToken.balanceOf(address(carbonTrader)), 1 * 10 ** 6); // 检查 CarbonTrader 的余额是否正确

        vm.prank(user1); // 模拟 user1 调用合约
        carbonTrader.refundDeposit(tradeID); // 退款
        assertEq(carbonTrader.getTradeDeposit(tradeID), 0); // 检查存款是否已退款

        // 检查 user1 的余额是否正确增加
        assertEq(usdtToken.balanceOf(user1), initialBalance); // user1 应该收到退款
    }

    function testFinalizeAuctionAndTransferCarbon() public {
        string memory tradeID = "trade1";
        uint256 initialOwnerBalance = usdtToken.balanceOf(
            address(carbonTrader)
        );
        vm.prank(owner);
        carbonTrader.issueAllowance(user1, 1000);
        vm.prank(user1);
        carbonTrader.startTrade(
            tradeID,
            1000,
            block.timestamp,
            block.timestamp + 1 weeks,
            100,
            1 * 10 ** 6
        );

        usdtToken.mint(user2, 1.5 * 10 ** 6); // 为 user2 铸造 1 USDT
        vm.prank(user2); // 模拟 user2 调用合约
        usdtToken.approve(address(carbonTrader), 1.5 * 10 ** 6); // 授权 CarbonTrader 合约支配 user2 的 1 USDT

        vm.prank(user2); // 模拟 user2 调用合约
        carbonTrader.deposit(tradeID, 1 * 10 ** 6, ""); // user2 存入 1 USDT
        assertEq(usdtToken.balanceOf(user2), 0.5 * 10 ** 6); // 检查 user2 是否正确扣除保证金
        assertEq(usdtToken.balanceOf(address(carbonTrader)), 1 * 10 ** 6); // 检查 CarbonTrader 的余额是否正确

        vm.prank(user2); // 模拟 user2 调用合约
        carbonTrader.finalizeAuctionAndTransferCarbon(
            tradeID,
            500,
            0.5 * 10 ** 6
        ); // 结束拍卖并转移碳额度
        assertEq(carbonTrader.getAllownance(user2), 500); // 检查是否正确转移碳额度
        assertEq(
            usdtToken.balanceOf(address(carbonTrader)),
            initialOwnerBalance + 1.5 * 10 ** 6
        ); // 检查 CarbonTrader 是否收到保证金和拍卖金额
        assertEq(usdtToken.balanceOf(user2), 0); // 检查 CarbonTrader 的余额是否正确
        assertEq(carbonTrader.getFrozenAllowance(user1), 500); // 检查是否正确扣除 user1 的冻结碳额度

        vm.prank(user1);
        assertEq(carbonTrader.getAuctionAmount(), 1.5 * 10 ** 6); // 检查 user1 是否收到拍卖金额
    }

    function testWithdrawAuctionAmount() public {
        string memory tradeID = "trade1";
        vm.prank(owner);
        carbonTrader.issueAllowance(user1, 1000);
        vm.prank(user1);
        carbonTrader.startTrade(
            tradeID,
            1000,
            block.timestamp,
            block.timestamp + 1 weeks,
            100,
            1 * 10 ** 6
        );

        usdtToken.mint(user2, 1.5 * 10 ** 6); // 为 user2 铸造 1 USDT
        vm.prank(user2); // 模拟 user2 调用合约
        usdtToken.approve(address(carbonTrader), 1.5 * 10 ** 6); // 授权 CarbonTrader 合约支配 user2 的 USDT

        vm.prank(user2);
        carbonTrader.deposit(tradeID, 1 * 10 ** 6, ""); // user2 存入 1 USDT

        vm.prank(user2); // 模拟 user2 调用合约
        carbonTrader.finalizeAuctionAndTransferCarbon(
            tradeID,
            500,
            0.5 * 10 ** 6
        ); // 结束拍卖并转移碳额度

        vm.prank(user1); // 模拟 owner 调用合约
        carbonTrader.withdrawAuctionAmount(); // 退款
        assertEq(usdtToken.balanceOf(user1), 1.5 * 10 ** 6); // 检查 owner 是否收到退款
    }
}
