// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {CarbonPortal} from "../src/CarbonPortal.sol";

contract DeployCarbonPortal is Script {
    function run() external returns (CarbonPortal) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
	address[] memory modules = new address[](0);
	address router = 0xAfA952790492DDeB474012cEA12ba34B788ab39F;
	address carbonContract = 0xb0FE540Db40150bEdeD399618E0F2cD7bE7251b9;
        CarbonPortal carbonPortal = new CarbonPortal(
            modules,
	    router,
	    carbonContract
        );
        vm.stopBroadcast();
        return carbonPortal;
    }
}


