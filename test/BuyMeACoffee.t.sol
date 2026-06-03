// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BuyMeACoffee} from "../src/BuyMeACoffee.sol";

/// @title BuyMeACoffee tests
/// @notice Proves every function behaves correctly. Run with `forge test -vv`.
contract BuyMeACoffeeTest is Test {
    BuyMeACoffee public coffee;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    event NewMemo(
        address indexed from,
        uint256 timestamp,
        string name,
        string message
    );

    function setUp() public {
        vm.prank(owner);
        coffee = new BuyMeACoffee();

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    /* -------------------------------------------------------------------- */
    /*                          Deployment / state                          */
    /* -------------------------------------------------------------------- */

    function test_OwnerIsSetOnDeployment() public view {
        assertEq(coffee.owner(), owner);
    }

    function test_StartsWithNoMemos() public view {
        BuyMeACoffee.Memo[] memory memos = coffee.getMemos();
        assertEq(memos.length, 0);
    }

    /* -------------------------------------------------------------------- */
    /*                              buyCoffee                               */
    /* -------------------------------------------------------------------- */

    function test_BuyCoffee_StoresTheMemo() public {
        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "Great work!");

        BuyMeACoffee.Memo[] memory memos = coffee.getMemos();

        assertEq(memos.length, 1);
        assertEq(memos[0].from, alice);
        assertEq(memos[0].name, "Alice");
        assertEq(memos[0].message, "Great work!");
    }

    function test_BuyCoffee_IncreasesContractBalance() public {
        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "Great work!");

        assertEq(address(coffee).balance, 1 ether);
    }

    function test_BuyCoffee_StoresMultipleMemos() public {
        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "First!");

        vm.prank(bob);
        coffee.buyCoffee{value: 2 ether}("Bob", "Keep it up");

        BuyMeACoffee.Memo[] memory memos = coffee.getMemos();

        assertEq(memos.length, 2);
        assertEq(memos[0].from, alice);
        assertEq(memos[1].from, bob);
        assertEq(address(coffee).balance, 3 ether);
    }

    function test_BuyCoffee_RevertsOnZeroTip() public {
        vm.expectRevert("Tip must be greater than zero");

        vm.prank(alice);
        coffee.buyCoffee{value: 0}("Alice", "Nope");
    }

    function test_BuyCoffee_EmitsNewMemoEvent() public {
        vm.expectEmit(true, false, false, true);
        emit NewMemo(alice, block.timestamp, "Alice", "Great work!");

        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "Great work!");
    }

    /* -------------------------------------------------------------------- */
    /*                             withdrawTips                             */
    /* -------------------------------------------------------------------- */

    function test_WithdrawTips_TransfersBalanceToOwner() public {
        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "Great work!");

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        coffee.withdrawTips();

        assertEq(owner.balance, ownerBalanceBefore + 1 ether);
        assertEq(address(coffee).balance, 0);
    }

    function test_WithdrawTips_RevertsForNonOwner() public {
        vm.prank(alice);
        coffee.buyCoffee{value: 1 ether}("Alice", "Great work!");

        vm.expectRevert("Only the owner can do this");

        vm.prank(alice);
        coffee.withdrawTips();
    }

    function test_WithdrawTips_RevertsWhenEmpty() public {
        vm.expectRevert("Nothing to withdraw");

        vm.prank(owner);
        coffee.withdrawTips();
    }
}