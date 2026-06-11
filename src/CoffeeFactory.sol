// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BuyMeACoffeeV2} from "./BuyMeACoffeeV2.sol";

/// @title  CoffeeFactory — one-click tip jars, one platform fee
/// @notice Anyone can spin up their own BuyMeACoffeeV2 tip jar through this
///         factory. Every jar is created with the factory's `platformOwner` set
///         as the fee recipient, so the platform earns a small fee on tips
///         across *all* jars — a real multi-creator earning model.
/// @dev    Fees never pass through the factory: each jar pays the platform
///         directly, so the platform withdraws fees from each jar (via the
///         jar's `withdrawPlatformFees()`), and creators withdraw their own
///         tips. The factory only deploys and indexes jars.
contract CoffeeFactory {
    // The platform — receives the fee on every jar this factory creates.
    address public immutable platformOwner;

    // Default fee (basis points) applied to newly created jars.
    uint16 public defaultFeeBps;
    uint16 public constant MAX_FEE_BPS = 1000; // 10% hard cap

    // Every jar ever created, and an index by creator.
    address[] public allJars;
    mapping(address => address[]) private jarsByCreator;

    event JarCreated(
        address indexed creator,
        address indexed jar,
        uint16 feeBps
    );
    event DefaultFeeUpdated(uint16 newFeeBps);

    /// @param _platformOwner The address that earns fees on every jar. Pass
    ///                       address(0) to default to the deployer. Use a
    ///                       wallet you control directly (it must be able to
    ///                       call `withdrawPlatformFees()` on each jar) — a
    ///                       hot deploy key can then stay free of funds.
    /// @param _defaultFeeBps Starting fee for new jars (<= MAX_FEE_BPS).
    constructor(address _platformOwner, uint16 _defaultFeeBps) {
        require(_defaultFeeBps <= MAX_FEE_BPS, "Fee too high");
        platformOwner = _platformOwner == address(0) ? msg.sender : _platformOwner;
        defaultFeeBps = _defaultFeeBps;
    }

    modifier onlyPlatform() {
        require(msg.sender == platformOwner, "Only the platform can do this");
        _;
    }

    /// @notice Create your own tip jar. You become its owner (and withdraw its
    ///         tips); the platform earns `defaultFeeBps` on each tip.
    /// @return jar The address of the newly deployed jar.
    function createJar() external returns (address jar) {
        BuyMeACoffeeV2 newJar = new BuyMeACoffeeV2(
            platformOwner, // fees flow to the platform, not this factory
            msg.sender, // the caller owns and withdraws this jar's tips
            defaultFeeBps
        );

        jar = address(newJar);
        allJars.push(jar);
        jarsByCreator[msg.sender].push(jar);

        emit JarCreated(msg.sender, jar, defaultFeeBps);
    }

    /// @notice Platform updates the fee used for *future* jars (cap-enforced).
    ///         Existing jars keep their fee unless the platform changes each one.
    function setDefaultFeeBps(uint16 _feeBps) external onlyPlatform {
        require(_feeBps <= MAX_FEE_BPS, "Fee too high");
        defaultFeeBps = _feeBps;
        emit DefaultFeeUpdated(_feeBps);
    }

    /// @notice All jars created by a given creator.
    function jarsOf(address creator) external view returns (address[] memory) {
        return jarsByCreator[creator];
    }

    /// @notice Every jar this factory has created.
    function getAllJars() external view returns (address[] memory) {
        return allJars;
    }

    /// @notice Total number of jars created.
    function jarCount() external view returns (uint256) {
        return allJars.length;
    }
}
