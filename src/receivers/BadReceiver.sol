// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title BadReceiver
/// @notice Deliberately does NOT implement tokenReceived and has no fallback
///         function. Stands in for an ordinary contract that was never built
///         to hold tokens — exactly the case ERC-223 protects against. Under
///         plain ERC-20, a transfer here would silently succeed and the
///         tokens would be stuck forever, since this contract has no way to
///         move tokens back out. Under ERC-223, the transfer call itself
///         reverts: there's no matching function selector and no fallback to
///         catch it, so the EVM call to tokenReceived fails, and because a
///         failed external call unwinds the caller too, ERC223Token's
///         balance changes are rolled back with it — the sender keeps their
///         tokens instead of losing them.
contract BadReceiver {
    // Intentionally empty. No tokenReceived, no fallback, no receive.
}
