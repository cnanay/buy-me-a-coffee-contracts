// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  BuyMeACoffeeV2 — tip jar with an optional platform fee
/// @notice Same tip jar as V1, but every tip is split: a configurable
///         percentage goes to the *platform* (whoever deploys this), and the
///         rest accrues to the *jar owner* (the creator being tipped).
/// @dev    This makes it a real earning model: run it as a platform, deploy a
///         jar per creator (jarOwner = the creator), and collect a small fee on
///         every tip. For your own single jar, set the fee to 0 and it behaves
///         exactly like V1. Backwards-compatible with the existing frontend:
///         `owner()`, `buyCoffee`, `withdrawTips`, `getMemos` and `NewMemo` are
///         unchanged, so the fee is invisible to tippers.
contract BuyMeACoffeeV2 {
    // The address that deploys the contract — collects the platform fee.
    address public immutable platformOwner;

    // The creator who receives the tips. Named `owner` for frontend parity.
    address public owner;

    // Platform fee in basis points (1% = 100 bps). Capped for trust.
    uint16 public feeBps;
    uint16 public constant MAX_FEE_BPS = 1000; // hard cap: 10%

    // Fees collected so far and not yet withdrawn by the platform. Tracked
    // separately so the jar owner can never withdraw the platform's cut.
    uint256 public platformFees;

    struct Memo {
        address from;
        uint256 timestamp;
        string name;
        string message;
    }

    Memo[] private memos;

    event NewMemo(
        address indexed from,
        uint256 timestamp,
        string name,
        string message
    );

    /// @notice Emitted on every tip with the gross amount and the fee taken.
    event TipReceived(address indexed from, uint256 amount, uint256 fee);
    event FeeUpdated(uint16 newFeeBps);

    /// @param _jarOwner Creator who withdraws the tips. Pass address(0) to use
    ///                  the deployer (i.e. a personal jar with no third party).
    /// @param _feeBps   Starting platform fee in basis points (<= MAX_FEE_BPS).
    constructor(address _jarOwner, uint16 _feeBps) {
        require(_feeBps <= MAX_FEE_BPS, "Fee too high");
        platformOwner = msg.sender;
        owner = _jarOwner == address(0) ? msg.sender : _jarOwner;
        feeBps = _feeBps;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can do this");
        _;
    }

    modifier onlyPlatform() {
        require(msg.sender == platformOwner, "Only the platform can do this");
        _;
    }

    /// @notice Send a tip with your name and a message.
    /// @dev    Splits off the platform fee, the remainder stays for the owner.
    function buyCoffee(string memory _name, string memory _message)
        public
        payable
    {
        require(msg.value > 0, "Tip must be greater than zero");

        uint256 fee = (msg.value * feeBps) / 10_000;
        platformFees += fee;

        memos.push(Memo(msg.sender, block.timestamp, _name, _message));

        emit NewMemo(msg.sender, block.timestamp, _name, _message);
        emit TipReceived(msg.sender, msg.value, fee);
    }

    /// @notice Owner withdraws their tips (everything except accrued fees).
    function withdrawTips() public onlyOwner {
        uint256 amount = address(this).balance - platformFees;
        require(amount > 0, "Nothing to withdraw");

        (bool success, ) = owner.call{value: amount}("");
        require(success, "Withdraw failed");
    }

    /// @notice Platform withdraws its accrued fees across all tips.
    function withdrawPlatformFees() public onlyPlatform {
        uint256 amount = platformFees;
        require(amount > 0, "No fees to withdraw");

        platformFees = 0; // effects before interaction (reentrancy-safe)

        (bool success, ) = platformOwner.call{value: amount}("");
        require(success, "Withdraw failed");
    }

    /// @notice Platform can adjust the fee, never above the hard cap.
    function setFeeBps(uint16 _feeBps) public onlyPlatform {
        require(_feeBps <= MAX_FEE_BPS, "Fee too high");
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    /// @notice The owner's currently withdrawable balance (excludes fees).
    function tipsBalance() public view returns (uint256) {
        return address(this).balance - platformFees;
    }

    /// @notice Returns every memo, for the frontend to display.
    function getMemos() public view returns (Memo[] memory) {
        return memos;
    }
}
