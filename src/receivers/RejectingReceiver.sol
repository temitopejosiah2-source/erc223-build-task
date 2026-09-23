// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC223Recipient} from "../IERC223Recipient.sol";

/// @title RejectingReceiver
/// @notice Implements the hook (so it's not the "missing function" case) but
///         always reverts inside it — e.g. a vault that's paused, or only
///         accepts a different token. Distinguishes "no hook exists" from
///         "hook exists and actively says no", which the spec treats the same
///         way: the transfer reverts either way.
contract RejectingReceiver is IERC223Recipient {
    error DepositsClosed();

    function tokenReceived(address, uint256, bytes calldata) external pure override returns (bytes4) {
        revert DepositsClosed();
    }
}
