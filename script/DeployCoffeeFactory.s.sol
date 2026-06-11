// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CoffeeFactory} from "../src/CoffeeFactory.sol";

/// @title  Deploy script for CoffeeFactory
/// @notice Deploys the factory. The platform (fee earner) is taken from the
///         PLATFORM_OWNER env var so the deploy key and the revenue wallet can
///         be different; if unset, the deployer becomes the platform.
/// @dev    The default fee for new jars (basis points) can be set via the
///         FACTORY_FEE_BPS env var, otherwise it defaults to 250 (2.5%).
contract DeployCoffeeFactory is Script {
    function run() external returns (CoffeeFactory) {
        // 250 bps = 2.5%. Override with `export FACTORY_FEE_BPS=...` before running.
        uint16 feeBps = uint16(vm.envOr("FACTORY_FEE_BPS", uint256(250)));
        // The wallet that earns all platform fees. address(0) = the deployer.
        address platformOwner = vm.envOr("PLATFORM_OWNER", address(0));

        vm.startBroadcast();
        CoffeeFactory factory = new CoffeeFactory(platformOwner, feeBps);
        vm.stopBroadcast();

        console.log("CoffeeFactory deployed at:", address(factory));
        console.log("Platform owner:", factory.platformOwner());
        console.log("Default fee (bps):", feeBps);
        return factory;
    }
}
