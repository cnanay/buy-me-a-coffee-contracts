// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CoffeeFactory} from "../src/CoffeeFactory.sol";
import {BuyMeACoffeeV2} from "../src/BuyMeACoffeeV2.sol";

/// @title CoffeeFactory tests
/// @notice Proves the multi-creator factory + fee routing. Run: forge test -vv
contract CoffeeFactoryTest is Test {
    CoffeeFactory public factory;

    address public platform = makeAddr("platform");
    address public creatorA = makeAddr("creatorA");
    address public creatorB = makeAddr("creatorB");
    address public tipper = makeAddr("tipper");

    uint16 public constant FEE = 250; // 2.5%

    event JarCreated(
        address indexed creator,
        address indexed jar,
        uint16 feeBps
    );

    function setUp() public {
        vm.prank(platform);
        factory = new CoffeeFactory(FEE);
        vm.deal(tipper, 10 ether);
    }

    /* -------------------------------------------------------------------- */
    /*                              Deployment                               */
    /* -------------------------------------------------------------------- */

    function test_DeploymentSetsPlatformAndFee() public view {
        assertEq(factory.platformOwner(), platform);
        assertEq(factory.defaultFeeBps(), FEE);
        assertEq(factory.jarCount(), 0);
    }

    function test_ConstructorRevertsAboveMaxFee() public {
        uint16 tooHigh = factory.MAX_FEE_BPS() + 1;
        vm.expectRevert("Fee too high");
        new CoffeeFactory(tooHigh);
    }

    /* -------------------------------------------------------------------- */
    /*                               createJar                              */
    /* -------------------------------------------------------------------- */

    function test_CreateJar_DeploysAndWiresCorrectly() public {
        vm.prank(creatorA);
        address jar = factory.createJar();

        BuyMeACoffeeV2 j = BuyMeACoffeeV2(jar);
        assertEq(j.owner(), creatorA); // creator owns their tips
        assertEq(j.platformOwner(), platform); // fees go to the platform
        assertEq(j.feeBps(), FEE);
    }

    function test_CreateJar_IndexesJar() public {
        vm.prank(creatorA);
        address jar = factory.createJar();

        assertEq(factory.jarCount(), 1);
        assertEq(factory.getAllJars()[0], jar);

        address[] memory aJars = factory.jarsOf(creatorA);
        assertEq(aJars.length, 1);
        assertEq(aJars[0], jar);
    }

    function test_CreateJar_EmitsEvent() public {
        // jar address (topic2) is unknown ahead of time, so we don't check it.
        vm.expectEmit(true, false, false, true);
        emit JarCreated(creatorA, address(0), FEE);

        vm.prank(creatorA);
        factory.createJar();
    }

    function test_MultipleCreatorsAndJars() public {
        vm.prank(creatorA);
        factory.createJar();
        vm.prank(creatorA);
        factory.createJar();
        vm.prank(creatorB);
        factory.createJar();

        assertEq(factory.jarCount(), 3);
        assertEq(factory.jarsOf(creatorA).length, 2);
        assertEq(factory.jarsOf(creatorB).length, 1);
    }

    /* -------------------------------------------------------------------- */
    /*                  Integration: fees reach the platform                */
    /* -------------------------------------------------------------------- */

    function test_FeesFlowToPlatform() public {
        vm.prank(creatorA);
        BuyMeACoffeeV2 jar = BuyMeACoffeeV2(factory.createJar());

        vm.prank(tipper);
        jar.buyCoffee{value: 1 ether}("Tipper", "thanks!");

        uint256 fee = (1 ether * uint256(FEE)) / 10_000;

        // Platform withdraws its fee straight from the jar (no ETH via factory).
        uint256 platformBefore = platform.balance;
        vm.prank(platform);
        jar.withdrawPlatformFees();
        assertEq(platform.balance, platformBefore + fee);

        // Creator withdraws their share.
        uint256 creatorBefore = creatorA.balance;
        vm.prank(creatorA);
        jar.withdrawTips();
        assertEq(creatorA.balance, creatorBefore + (1 ether - fee));
    }

    /* -------------------------------------------------------------------- */
    /*                            setDefaultFeeBps                          */
    /* -------------------------------------------------------------------- */

    function test_SetDefaultFee_AffectsFutureJarsOnly() public {
        vm.prank(creatorA);
        address jar1 = factory.createJar(); // created at FEE

        vm.prank(platform);
        factory.setDefaultFeeBps(500);

        vm.prank(creatorB);
        address jar2 = factory.createJar(); // created at 500

        assertEq(BuyMeACoffeeV2(jar1).feeBps(), FEE);
        assertEq(BuyMeACoffeeV2(jar2).feeBps(), 500);
        assertEq(factory.defaultFeeBps(), 500);
    }

    function test_SetDefaultFee_RevertsForNonPlatform() public {
        vm.expectRevert("Only the platform can do this");
        vm.prank(creatorA);
        factory.setDefaultFeeBps(500);
    }

    function test_SetDefaultFee_RevertsAboveCap() public {
        uint16 tooHigh = factory.MAX_FEE_BPS() + 1;
        vm.expectRevert("Fee too high");
        vm.prank(platform);
        factory.setDefaultFeeBps(tooHigh);
    }
}
