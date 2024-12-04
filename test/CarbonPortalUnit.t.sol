// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AttestationRegistry} from "@verax-attestation-registry/verax-contracts/contracts/AttestationRegistry.sol";
import {ModuleRegistry} from "@verax-attestation-registry/verax-contracts/contracts/ModuleRegistry.sol";
import {PortalRegistry} from "@verax-attestation-registry/verax-contracts/contracts/PortalRegistry.sol";
import {SchemaRegistry} from "@verax-attestation-registry/verax-contracts/contracts/SchemaRegistry.sol";
import {Router} from "@verax-attestation-registry/verax-contracts/contracts/Router.sol";
import {AttestationPayload, Attestation} from "@verax-attestation-registry/verax-contracts/contracts/types/Structs.sol";
import "../src/CarbonPortal.sol";

contract CarbonPortalUint is Test {
    AttestationRegistry attestationRegistry;
    ModuleRegistry moduleRegistry;
    PortalRegistry portalRegistry;
    SchemaRegistry schemaRegistry;
    Router router;
    CarbonPortal carbonPortal;

    address owner = address(this);
    address attester = address(0x1234);
    address zero = address(0x00);
    bytes32 schemaId = 0x1064602e605302c554fa75e1ee5b65ac8bd5d962abd0830f73840ca138b3b1c7;

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
    }

    function testAttest() public {
        vm.startPrank(owner);
        carbonPortal.uploadAttest(owner);
        Attestation memory attestation = carbonPortal.getAttestation(owner);
        console.logBytes32(attestation.schemaId);
        console.logBytes(attestation.subject);
        console.logBytes(attestation.attestationData);
        assertEq(carbonPortal.isMember(owner), true);
        vm.stopPrank();
    }
}
