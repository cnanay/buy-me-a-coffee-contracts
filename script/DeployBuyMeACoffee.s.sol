// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BuyMeACoffee} from "../src/BuyMeACoffee.sol";

/// @title Deploy script for BuyMeACoffee
/// @notice Deploys the contract to whichever network forge is pointed at.
contract DeployBuyMeACoffee is Script {
    function run() external returns (BuyMeACoffee) {
        // vm.startBroadcast tells Foundry to send the following transactions
        // to the real network, signed by the private key from --private-key.
        vm.startBroadcast();

        BuyMeACoffee coffee = new BuyMeACoffee();

        vm.stopBroadcast();

        console.log("BuyMeACoffee deployed at:", address(coffee));
        return coffee;
    }
}