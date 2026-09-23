// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC223Recipient} from "./IERC223Recipient.sol";

/// @title ERC223Token
/// @notice A scoped-down ERC-223 implementation. See eips.ethereum.org/EIPS/eip-223.
///
/// @dev What this fixes, in one sentence: plain ERC-20's `transfer` has no way
///      to tell a receiving contract "you just got paid", so tokens sent to a
///      contract that isn't expecting them (wrong address, a contract that was
///      never meant to hold tokens, a typo'd deposit) sit there forever with no
///      way to get them out. ERC-223 makes `transfer` call a hook on the
///      recipient if it's a contract, and REVERTS if that hook is missing or
///      rejects the call — so a bad transfer to a contract fails loudly at the
///      point of sending, instead of silently succeeding and locking the funds.
///
///      DESIGN DECISION: the original ERC-223 spec drops `approve`/`transferFrom`
///      entirely (that pattern is exactly the ERC-20 behavior this proposal is
///      reacting against). This task is scoped to the receiver-hook mechanism,
///      so I implemented only `transfer` and left `approve`/`transferFrom` out
///      rather than bolting on an ERC-20-style allowance system that the spec
///      doesn't call for. Documented in the design note.
contract ERC223Token {
    /// @dev Per spec "Receiver Methods": the value tokenReceived must return.
    ///      Kept as a named constant so it's grep-able against the spec text
    ///      instead of a magic number sitting in a comment.
    bytes4 public constant ERC223_MAGIC_VALUE = 0x8943ec02;

    string public name;
    string public symbol;
    // Per the spec's reference implementation, decimals is set once at
    // construction (new_decimals), not hardcoded — the spec only fixes the
    // *default* convention (18, mirroring ETH/wei) as what most tokens choose.
    uint8 public immutable decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    /// @dev ERC-223's own Transfer event carries the extra `data` field so a
    ///      block explorer or indexer can see what was passed to the receiver
    ///      hook, not just that a transfer happened. Signature matches the
    ///      spec's Events section exactly.
    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);

    error InsufficientBalance(address from, uint256 balance, uint256 amount);
    error TransferToZeroAddress();

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 initialSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;
        emit Transfer(address(0), msg.sender, initialSupply, "");
    }

    /// @notice Transfer with no extra data. Matches the plain `transfer(to, value)`
    ///         signature people expect from ERC-20, but routed through the same
    ///         hook-checking logic as `transfer(to, value, data)`.
    /// @dev The spec's own reference implementation passes `hex"00000000"` —
    ///      four zero bytes, not truly empty bytes — as the `_data` argument
    ///      for this overload. That's an unusual, specific choice (most
    ///      real-world clones just use `""`), but since the task asks to
    ///      implement the published spec rather than a generic reinvention,
    ///      this mirrors the reference implementation's exact behavior.
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(to, value, hex"00000000");
        return true;
    }

    /// @notice Transfer with attached data, forwarded to the receiver's hook.
    function transfer(address to, uint256 value, bytes calldata data) external returns (bool) {
        _transfer(to, value, data);
        return true;
    }

    function _transfer(address to, uint256 value, bytes memory data) internal {
        if (to == address(0)) revert TransferToZeroAddress();

        uint256 fromBalance = balanceOf[msg.sender];
        if (fromBalance < value) revert InsufficientBalance(msg.sender, fromBalance, value);

        // Effects before interaction, so a reentrant call from a malicious
        // receiver hook can't see an inconsistent balance.
        unchecked {
            balanceOf[msg.sender] = fromBalance - value;
        }
        balanceOf[to] += value;

        if (_isContract(to)) {
            // This is the whole mechanism: if `to` is a contract, it MUST
            // implement tokenReceived. If it doesn't (no matching function and
            // no fallback), or if it reverts on purpose, this call reverts —
            // and because Solidity external calls that revert unwind the
            // caller too, the balance changes above are rolled back with it.
            // No separate try/catch: we want a missing or failing hook to be
            // a hard failure, not a silent "sent anyway".
            IERC223Recipient(to).tokenReceived(msg.sender, value, data);
        }
        // to a wallet (no code): nothing further needed, balances above are the transfer.

        emit Transfer(msg.sender, to, value, data);
    }

    /// @dev `to.code.length > 0` is the standard way to distinguish a contract
    ///      from a wallet at the point of the call. It's not perfect — a
    ///      contract's constructor has zero code length while it's still
    ///      running — but that edge case is out of scope here and is the same
    ///      limitation real ERC-223 implementations accept.
    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
