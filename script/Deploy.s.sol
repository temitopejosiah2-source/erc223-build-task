// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC223Token} from "../src/ERC223Token.sol";
import {GoodReceiver} from "../src/receivers/GoodReceiver.sol";
import {BadReceiver} from "../src/receivers/BadReceiver.sol";
import {RejectingReceiver} from "../src/receivers/RejectingReceiver.sol";

contract Deploy is Script {
    function run()
        external
        returns (
            ERC223Token token,
            GoodReceiver good,
            BadReceiver bad,
            RejectingReceiver rejecting
        )
    {
        vm.startBroadcast();
        token = new ERC223Token("Demo223", "D223", 18, 1_000_000e18);
        good = new GoodReceiver();
        bad = new BadReceiver();
        rejecting = new RejectingReceiver();
        vm.stopBroadcast();

        console2.log("ERC223Token:      ", address(token));
        console2.log("GoodReceiver:     ", address(good));
        console2.log("BadReceiver:      ", address(bad));
        console2.log("RejectingReceiver:", address(rejecting));
    }
}