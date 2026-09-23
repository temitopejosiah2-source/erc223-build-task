// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IERC223Recipient
/// @notice Any contract that wants to receive ERC223Token must implement this.
///         `transfer` calls this on the recipient; if the call fails (including
///         "no such function", which happens automatically when a contract
///         hasn't implemented it and has no matching fallback) the whole
///         transfer reverts. This is the mechanism that prevents tokens from
///         getting stuck in a contract that isn't expecting them.
///
/// @dev Per the published spec (eips.ethereum.org/EIPS/eip-223, "Receiver
///      Methods"): "The tokenReceived function must return 0x8943ec02 after
///      handling an incoming token transfer." The function signature itself
///      (name + parameter types) is what actually gets checked by Solidity's
///      call dispatch — a contract with no matching function reverts
///      regardless of what it would have returned — but returning the magic
///      value is still part of the formal interface, so this implementation
///      matches it exactly rather than dropping the return type.
interface IERC223Recipient {
    /// @return magicValue must be 0x8943ec02 (see ERC223Token.ERC223_MAGIC_VALUE)
    function tokenReceived(address from, uint256 value, bytes calldata data) external returns (bytes4 magicValue);
}
