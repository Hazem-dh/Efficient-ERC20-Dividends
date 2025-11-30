// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Token} from "../src/Token.sol";
contract CounterScript is Script {
    Token public token;
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        token = new Token();

        vm.stopBroadcast();
    }
}
