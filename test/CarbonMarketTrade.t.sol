// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
//import {CarbonAllowanceManager} from "../../src/CarbonAllowanceManager.sol";
import {CarbonMarketTrade} from "../src/CarbonMarketTrade.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
// ======================= verax ========================
import {AttestationRegistry} from "@verax-attestation-registry/verax-contracts/contracts/AttestationRegistry.sol";
import {ModuleRegistry} from "@verax-attestation-registry/verax-contracts/contracts/ModuleRegistry.sol";
import {PortalRegistry} from "@verax-attestation-registry/verax-contracts/contracts/PortalRegistry.sol";
import {SchemaRegistry} from "@verax-attestation-registry/verax-contracts/contracts/SchemaRegistry.sol";
import {Router} from "@verax-attestation-registry/verax-contracts/contracts/Router.sol";
import {AttestationPayload, Attestation} from "@verax-attestation-registry/verax-contracts/contracts/types/Structs.sol";
import "../src/CarbonPortal.sol";

contract CarbonMarketTradeTest is Test {
    CarbonMarketTrade carbonMarketTrade;
    ERC20Mock erc20Mock;
    // verax
    AttestationRegistry attestationRegistry;
    ModuleRegistry moduleRegistry;
    PortalRegistry portalRegistry;
    SchemaRegistry schemaRegistry;
    Router router;
    CarbonPortal carbonPortal;

    address owner = address(this);
    address seller = address(0x1234);
    address buyer = address(0x5678);
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
        carbonMarketTrade = new CarbonMarketTrade(address(erc20Mock));
        carbonMarketTrade.updateCarbonPortal(address(carbonPortal));
        vm.stopPrank();
        
        carbonPortal.updateCarbonContract(address(carbonMarketTrade));
    }

    function testMarketTrade() public {
        // CarbonMarketTrade.MarketTrade storage marketTrade;
        vm.startPrank(owner);
        erc20Mock.mint(seller, 1000);
        erc20Mock.mint(buyer, 1000);

        // issueAllowance
        carbonMarketTrade.issueAllowance(owner, 10);
        assertEq(carbonMarketTrade.addressToAllowances(owner), 10);
        assertEq(carbonMarketTrade.isMember(owner), true);
        carbonMarketTrade.issueAllowance(seller, 5);
        carbonMarketTrade.issueAllowance(buyer, 2);
        vm.stopPrank();

        // createMarketTrade
        vm.prank(seller);
        carbonMarketTrade.createMarketTrade(13579, 3, 58);
        /*
        marketTrade = carbonMarketTrade.marketTrades(13579);
        assertEq(marketTrade.seller, seller);
        assertEq(marketTrade.amount, 3);
        assertEq(marketTrade.priceOfUint, 58);
        assertEq(marketTrade.status, CarbonMarketTrade.MarketTradeStatus.Trading);
        */
        // updateMarketTrade
        vm.prank(seller);
        carbonMarketTrade.updateMarketTrade(13579, 4, 50);
        /*
        marketTrade = carbonMarketTrade.marketTrades(13579);
        assertEq(marketTrade.seller, seller);
        assertEq(marketTrade.amount, 4);
        assertEq(marketTrade.priceOfUint, 50);
        assertEq(marketTrade.status, CarbonMarketTrade.MarketTradeStatus.Trading);
        */

        // makeADeal
        vm.startPrank(buyer);
        erc20Mock.approve(address(carbonMarketTrade), 1000);
        carbonMarketTrade.makeADeal(13579);
        vm.stopPrank();

        assertEq(carbonMarketTrade.addressToAllowances(seller), 1);
        assertEq(carbonMarketTrade.addressToAllowances(buyer), 6);
        assertEq(erc20Mock.balanceOf(seller), 1200);
        assertEq(erc20Mock.balanceOf(buyer), 800);
    }

    function testCancelMarketTrade() public {
        CarbonMarketTrade.MarketTrade storage marketTrade;
        vm.startPrank(owner);

        // issueAllowance
        carbonMarketTrade.issueAllowance(owner, 10);
        
        // createMarketTrade
        carbonMarketTrade.createMarketTrade(13579, 3, 58);

        // cancelMarketTrade
        carbonMarketTrade.cancelMarketTrade(13579);

        // marketTrade = carbonMarketTrade.marketTrades(13579);
        // assertEq(marketTrade.status, CarbonMarketTrade.MarketTradeStatus.End);
        assertEq(carbonMarketTrade.addressToAllowances(owner), 10);
    }
}
