// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {CarbonTrader} from "../src/CarbonTrader.sol";

contract DeployCarbonTrader is Script {
    function run() external returns (CarbonTrader) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        CarbonTrader carbonTrader = new CarbonTrader(
            address(0xFE8cD4998825256Aa61F58383840f0e09Cde1085)
        );
        vm.stopBroadcast();
        return carbonTrader;
    }
}
