// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title BuyMeACoffee
/// @notice A simple tip jar dApp. Anyone can send a tip with a name and a
///         message; only the owner can withdraw the collected funds.
/// @dev    My first end-to-end project. Read every line and make sure you
///         understand WHY it's there before you change anything.
contract BuyMeACoffee {
    // The address that deploys the contract becomes the owner and the only
    // account allowed to withdraw the tips.
    address public owner;

    // A single supporter's tip, stored permanently on-chain.
    struct Memo {
        address from;       // who sent the tip
        uint256 timestamp;  // when (block time)
        string name;        // their display name
        string message;     // their message to you
    }

    // Every memo ever sent. Kept private; read it through getMemos() below.
    Memo[] private memos;

    // Emitted on every new tip. Your frontend listens for this to update live.
    event NewMemo(
        address indexed from,
        uint256 timestamp,
        string name,
        string message
    );

    // Runs once, at deployment. Sets the deployer as the owner.
    constructor() {
        owner = msg.sender;
    }

    // Reusable check: restricts a function to the owner only.
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can do this");
        _; // the rest of the function runs here if the check passed
    }

    /// @notice Send a tip along with your name and a message.
    /// @dev    `payable` lets this function receive ETH. msg.value is the
    ///         amount sent. We reject zero-value tips.
    function buyCoffee(string memory _name, string memory _message)
        public
        payable
    {
        require(msg.value > 0, "Tip must be greater than zero");

        memos.push(Memo(msg.sender, block.timestamp, _name, _message));

        emit NewMemo(msg.sender, block.timestamp, _name, _message);
    }

    /// @notice Owner withdraws all collected tips to their own wallet.
    /// @dev    Uses the low-level `call` pattern, which is the current best
    ///         practice for sending ETH (safer than transfer/send).
    function withdrawTips() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Nothing to withdraw");

        (bool success, ) = owner.call{value: balance}("");
        require(success, "Withdraw failed");
    }

    /// @notice Returns every memo, for the frontend to display.
    /// @dev    Fine for a learning project. In production you'd paginate,
    ///         because returning a huge array gets expensive.
    function getMemos() public view returns (Memo[] memory) {
        return memos;
    }
}
