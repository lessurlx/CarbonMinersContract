// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
//import {CarbonAllowanceManager} from "../../src/CarbonAllowanceManager.sol";
import {CarbonAuctionTrade} from "../src/CarbonAuctionTrade.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
// ======================= verax ========================
import {AttestationRegistry} from "@verax-attestation-registry/verax-contracts/contracts/AttestationRegistry.sol";
import {ModuleRegistry} from "@verax-attestation-registry/verax-contracts/contracts/ModuleRegistry.sol";
import {PortalRegistry} from "@verax-attestation-registry/verax-contracts/contracts/PortalRegistry.sol";
import {SchemaRegistry} from "@verax-attestation-registry/verax-contracts/contracts/SchemaRegistry.sol";
import {Router} from "@verax-attestation-registry/verax-contracts/contracts/Router.sol";
import {AttestationPayload, Attestation} from "@verax-attestation-registry/verax-contracts/contracts/types/Structs.sol";
import "../src/CarbonPortal.sol";

contract CarbonAuctionTradeTest is Test {
    CarbonAuctionTrade carbonAuctionTrade;
    ERC20Mock erc20Mock;
    // verax
    AttestationRegistry attestationRegistry;
    ModuleRegistry moduleRegistry;
    PortalRegistry portalRegistry;
    SchemaRegistry schemaRegistry;
    Router router;
    CarbonPortal carbonPortal;

    address owner = address(this);
    address bidder1 = address(0x1234);
    address bidder2 = address(0x2345);
    address bidder3 = address(0x3456);
    address zero = address(0x00);

    function setUp() public {
        // mock verax
        attestationRegistry = new AttestationRegistry();
        moduleRegistry = new ModuleRegistry();
        portalRegistry = new PortalRegistry(true);
        schemaRegistry = new SchemaRegistry();
        router = new Router();
        router.initialize();

        // init router
        router.updateAttestationRegistry(address(attestationRegistry));
        router.updateModuleRegistry(address(moduleRegistry));
        router.updatePortalRegistry(address(portalRegistry));
        router.updateSchemaRegistry(address(schemaRegistry));
        vm.startPrank(zero);
        // init 
        portalRegistry.updateRouter(address(router));
        schemaRegistry.updateRouter(address(router));
        attestationRegistry.updateRouter(address(router));
        vm.stopPrank();

        // 1. registry schema
        string memory name = "Carbon";
        string memory description = "Member identity proof";
        string memory context = "https://schema.org/Property";
        string memory schemaString = "(bool isCarbonTradeMember)";
        schemaRegistry.createSchema(name, description, context, schemaString);

        // 2. deploy && registry carbonPortal
        address[] memory modules = new address[](0);
        carbonPortal = new CarbonPortal(modules, address(router), owner);
        portalRegistry.register(address(carbonPortal), "Carbon Portal", "Carbon attestations", true, "Carbon Member");

        vm.startPrank(owner);
        erc20Mock = new ERC20Mock("Carbon Miner Stablecoin", "CMS", owner, 10000);
        carbonAuctionTrade = new CarbonAuctionTrade(address(erc20Mock));
        carbonAuctionTrade.updateCarbonPortal(address(carbonPortal));
        vm.stopPrank();
        
        carbonPortal.updateCarbonContract(address(carbonAuctionTrade));
    }

    function testAuctionTrade() public {
        //carbonAuctionTrade.AuctionTrade storage auctionTrade;
        vm.startPrank(owner);
        erc20Mock.mint(bidder1, 1000);
        erc20Mock.mint(bidder2, 1000);
        erc20Mock.mint(bidder3, 1000);
        // issueAllowance
        carbonAuctionTrade.issueAllowance(owner, 10);
        assertEq(carbonAuctionTrade.addressToAllowances(owner), 10);
        assertEq(carbonAuctionTrade.isMember(owner), true);
        carbonAuctionTrade.issueAllowance(bidder1, 2);
        carbonAuctionTrade.issueAllowance(bidder2, 2);
        carbonAuctionTrade.issueAllowance(bidder3, 2);

        // startAuctionTrade
        carbonAuctionTrade.startAuctionTrade(
            13579,  // tradeID
            5,   // amount
            block.timestamp,   // startTimeStamp
            block.timestamp + 1 days,    //endTimeStamp
            1,  // minimumBidAmount
            68 // initPriceOfUint CMS
        );
        //auctionTrade = CarbonAuctionTrade.AuctionTrade(carbonAuctionTrade.auctionTrades(13579));
        /*
        assertEq(carbonAuctionTrade.auctionTrades(13579).seller, owner);
        assertEq(carbonAuctionTrade.auctionTrades(13579).amount, 5);
        assertEq(carbonAuctionTrade.auctionTrades(13579).startTimeStamp, block.timestamp);
        assertEq(carbonAuctionTrade.auctionTrades(13579).endTimeStamp, block.timestamp + 1 days);
        assertEq(carbonAuctionTrade.auctionTrades(13579).minimumBidAmount, 1);
        assertEq(carbonAuctionTrade.auctionTrades(13579).initPriceOfUint, 68);
        */
        vm.stopPrank();

        // deposit (bid)
        vm.startPrank(bidder1);
        erc20Mock.approve(address(carbonAuctionTrade), 1000);
        carbonAuctionTrade.deposit(13579, 68, "bidder1Bidinfo");
        vm.stopPrank();

        vm.startPrank(bidder2);
        erc20Mock.approve(address(carbonAuctionTrade), 1000);
        carbonAuctionTrade.deposit(13579, 68, "bidder2Bidinfo");
        vm.stopPrank();

        vm.startPrank(bidder3);
        erc20Mock.approve(address(carbonAuctionTrade), 1000);
        carbonAuctionTrade.deposit(13579, 68, "bidder3Bidinfo");
        vm.stopPrank();

        // uploadBidWinner
        vm.startPrank(owner);
        address[] memory bidders = new address[](2);
        bidders[0] = bidder1;
        bidders[1] = bidder2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2;
        amounts[1] = 3;

        uint256[] memory priceOfUnit = new uint256[](2);
        priceOfUnit[0] = 80;
        priceOfUnit[1] = 75;
        carbonAuctionTrade.uploadBidWinner(13579, bidders, amounts, priceOfUnit);
        vm.stopPrank();

        // finalizeAuctionAndTransferCarbon
        vm.prank(bidder1);
        carbonAuctionTrade.finalizeAuctionAndTransferCarbon(13579, 80*2 - 68);
        vm.prank(bidder2);
        carbonAuctionTrade.finalizeAuctionAndTransferCarbon(13579, 75*3 - 68);
        assertEq(carbonAuctionTrade.addressToAllowances(bidder1), 4);
        assertEq(carbonAuctionTrade.addressToAllowances(bidder2), 5);
        assertEq(carbonAuctionTrade.addressToAllowances(owner), 5);

        // refundDeposit
        vm.prank(bidder3);
        carbonAuctionTrade.refundDeposit(13579);
        assertEq(erc20Mock.balanceOf(bidder3), 1000);

        // withdrawAuctionAmount
        vm.prank(owner);
        carbonAuctionTrade.withdrawAuctionAmount();
        assertEq(erc20Mock.balanceOf(owner), 10385);
    }
}
