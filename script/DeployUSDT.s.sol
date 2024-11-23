// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {USDT} from "../src/USDT.sol";

contract DeployUSDT is Script {
    function run() external returns (USDT) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        USDT usdt = new USDT(
            "USDT for Carbon",
            "USDT",
            10000
        );
        vm.stopBroadcast();
        return usdt;
    }
}
