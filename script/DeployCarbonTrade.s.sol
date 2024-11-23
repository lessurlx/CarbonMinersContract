// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {CarbonTrader} from "../src/CarbonTrader.sol";

contract DeployCarbonTrade is Script {
    function run() external returns (CarbonTrader) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        CarbonTrader carbonTrader = new CarbonTrader(
            address(0xf0c75d5f53DeC8294101B474F77aEC13E444f6a3)
        );
        vm.stopBroadcast();
        return carbonTrader;
    }
}

