// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BuyMeACoffeeV2} from "../src/BuyMeACoffeeV2.sol";

/// @title BuyMeACoffeeV2 tests
/// @notice Proves the platform-fee split behaves correctly. Run: forge test -vv
contract BuyMeACoffeeV2Test is Test {
    BuyMeACoffeeV2 public coffee;

    address public platform = makeAddr("platform"); // deployer
    address public creator = makeAddr("creator"); // jar owner
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint16 public constant FEE_BPS = 250; // 2.5%

    event TipReceived(address indexed from, uint256 amount, uint256 fee);
    event FeeUpdated(uint16 newFeeBps);

    function setUp() public {
        vm.prank(platform);
        coffee = new BuyMeACoffeeV2(creator, FEE_BPS);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    /* -------------------------------------------------------------------- */
    /*                          Deployment / config                         */
    /* -------------------------------------------------------------------- */

    function test_DeploymentSetsRoles() public view {
        assertEq(coffee.platformOwner(), platform);
        assertEq(coffee.owner(), creator);
        assertEq(coffee.feeBps(), FEE_BPS);
    }

    function test_ZeroJarOwnerDefaultsToDeployer() public {
        vm.prank(platform);
        BuyMeACoffeeV2 personal = new BuyMeACoffeeV2(address(0), 0);
        assertEq(personal.owner(), platform);
        assertEq(personal.platformOwner(), platform);
    }

    function test_ConstructorRevertsAboveMaxFee() public {
        uint16 tooHigh = coffee.MAX_FEE_BPS() + 1;
        vm.expectRevert("Fee too high");
        new BuyMeACoffeeV2(creator, tooHigh);
    }

    /* -------------------------------------------------------------------- */
    /*                          Fee split on tips                           */
    /* -------------------------------------------------------------------- */

    function test_BuyCoffee_SplitsFee() public {
        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "Great work!");

        uint256 expectedFee = (1 ether * uint256(FEE_BPS)) / 10_000; // 0.025 ETH
        assertEq(coffee.platformFees(), expectedFee);
        assertEq(coffee.tipsBalance(), 1 ether - expectedFee);
        assertEq(address(coffee).balance, 1 ether);
    }

    function test_BuyCoffee_EmitsTipReceived() public {
        uint256 expectedFee = (1 ether * uint256(FEE_BPS)) / 10_000;
        vm.expectEmit(true, false, false, true);
        emit TipReceived(alice, 1 ether, expectedFee);

        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "Great work!");
    }

    function test_BuyCoffee_RevertsOnZeroTip() public {
        vm.expectRevert("Tip must be greater than zero");
        vm.prank(alice);
        coffee.buyCoffee{value: 0}("Alice", "Nope");
    }

    function test_ZeroFeeBehavesLikeV1() public {
        vm.prank(platform);
        BuyMeACoffeeV2 free = new BuyMeACoffeeV2(creator, 0);

        vm.prank(alice);
        free.buyCoffee{value: 1 ether}("Alice", "Hi");

        assertEq(free.platformFees(), 0);
        assertEq(free.tipsBalance(), 1 ether);
    }

    /* -------------------------------------------------------------------- */
    /*                             Withdrawals                              */
    /* -------------------------------------------------------------------- */

    function test_WithdrawTips_PaysOwnerMinusFees() public {
        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "Great work!");

        uint256 fee = (1 ether * uint256(FEE_BPS)) / 10_000;
        uint256 before = creator.balance;

        vm.prank(creator);
        coffee.withdrawTips();

        assertEq(creator.balance, before + (1 ether - fee));
        // The platform's fee stays in the contract until they withdraw it.
        assertEq(address(coffee).balance, fee);
        assertEq(coffee.platformFees(), fee);
    }

    function test_WithdrawTips_RevertsForNonOwner() public {
        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "x");

        vm.expectRevert("Only the owner can do this");
        vm.prank(alice);
        coffee.withdrawTips();
    }

    function test_WithdrawPlatformFees_PaysPlatform() public {
        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "x");

        uint256 fee = (1 ether * uint256(FEE_BPS)) / 10_000;
        uint256 before = platform.balance;

        vm.prank(platform);
        coffee.withdrawPlatformFees();

        assertEq(platform.balance, before + fee);
        assertEq(coffee.platformFees(), 0);
    }

    function test_WithdrawPlatformFees_RevertsForNonPlatform() public {
        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "x");

        vm.expectRevert("Only the platform can do this");
        vm.prank(creator);
        coffee.withdrawPlatformFees();
    }

    function test_OwnerCannotTouchPlatformFees() public {
        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "x");

        uint256 fee = (1 ether * uint256(FEE_BPS)) / 10_000;

        vm.prank(creator);
        coffee.withdrawTips();

        // After the owner withdraws, exactly the fee remains for the platform.
        assertEq(address(coffee).balance, fee);
    }

    /* -------------------------------------------------------------------- */
    /*                              setFeeBps                               */
    /* -------------------------------------------------------------------- */

    function test_SetFeeBps_UpdatesAndEmits() public {
        vm.expectEmit(false, false, false, true);
        emit FeeUpdated(500);

        vm.prank(platform);
        coffee.setFeeBps(500);

        assertEq(coffee.feeBps(), 500);
    }

    function test_SetFeeBps_RevertsAboveCap() public {
        uint16 tooHigh = coffee.MAX_FEE_BPS() + 1;
        vm.expectRevert("Fee too high");
        vm.prank(platform);
        coffee.setFeeBps(tooHigh);
    }

    function test_SetFeeBps_RevertsForNonPlatform() public {
        vm.expectRevert("Only the platform can do this");
        vm.prank(creator);
        coffee.setFeeBps(500);
    }
}
