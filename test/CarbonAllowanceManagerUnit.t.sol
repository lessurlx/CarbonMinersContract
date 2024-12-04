// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CarbonAllowanceManager} from "../src/CarbonAllowanceManager.sol";
// ======================= verax ========================
import {AttestationRegistry} from "@verax-attestation-registry/verax-contracts/contracts/AttestationRegistry.sol";
import {ModuleRegistry} from "@verax-attestation-registry/verax-contracts/contracts/ModuleRegistry.sol";
import {PortalRegistry} from "@verax-attestation-registry/verax-contracts/contracts/PortalRegistry.sol";
import {SchemaRegistry} from "@verax-attestation-registry/verax-contracts/contracts/SchemaRegistry.sol";
import {Router} from "@verax-attestation-registry/verax-contracts/contracts/Router.sol";
import {AttestationPayload, Attestation} from "@verax-attestation-registry/verax-contracts/contracts/types/Structs.sol";
import "../src/CarbonPortal.sol";

contract CarbonAllowanceManagerUnit is Test {
    CarbonAllowanceManager cam;
    // verax
    AttestationRegistry attestationRegistry;
    ModuleRegistry moduleRegistry;
    PortalRegistry portalRegistry = PortalRegistry(0xF35fe79104e157703dbCC3Baa72a81A99591744D);
    SchemaRegistry schemaRegistry;
    Router router = Router(0xAfA952790492DDeB474012cEA12ba34B788ab39F);
    CarbonPortal carbonPortal;

    address owner = address(this);
    address user = address(0x1234);
    address zero = address(0x00);

    function setUp() public {
        // mock verax
    /*
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
    */
        // 2. deploy && registry carbonPortal
        address[] memory modules = new address[](0);
        carbonPortal = new CarbonPortal(modules, address(router), owner);
        portalRegistry.register(address(carbonPortal), "Carbon Portal", "Carbon attestations", true, "Carbon Member");

        vm.startPrank(owner);
        cam = new CarbonAllowanceManager();
        cam.updateCarbonPortal(address(carbonPortal));
        vm.stopPrank();
        
        carbonPortal.updateCarbonContract(address(cam));
    }

    function testUpdateOwner() public {
        vm.prank(owner);
        cam.updateOwner(user);
        assertEq(cam.owner(), user);
    }

    function testNotOwner() public {
        vm.prank(user);
        // error CarbonManager__NotOwner(address, address);
        vm.expectRevert(abi.encodeWithSelector(CarbonAllowanceManager.CarbonManager__NotOwner.selector, owner, user));
        cam.updateOwner(user);
    }

    function testIssueAllowance() public {
        vm.startPrank(owner);
        cam.issueAllowance(user, 100);
        assertEq(cam.addressToAllowances(user), 100);
        assertEq(cam.isMember(user), true);
        vm.stopPrank();
    }

    function testFreezeAndDestory() public {
        vm.startPrank(owner);
        cam.issueAllowance(user, 100);

        // test freezeAllowance
        cam.freezeAllowance(user, 20);
        assertEq(cam.addressToAllowances(user), 80);
        assertEq(cam.frozenAllowances(user), 20);

        // test unfreezeAllowance
        cam.unfreezeAllowance(user, 10);
        assertEq(cam.addressToAllowances(user), 90);
        assertEq(cam.frozenAllowances(user), 10);

        // test destoryAllowance
        cam.destoryAllowance(user, 40);
        assertEq(cam.addressToAllowances(user), 50);

        // test destoryAllAllowance
        cam.destoryAllAllowance(user);
        assertEq(cam.addressToAllowances(user), 0);
        assertEq(cam.frozenAllowances(user), 0);
    }
}
