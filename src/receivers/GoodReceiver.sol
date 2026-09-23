// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC223Recipient} from "../IERC223Recipient.sol";

/// @title GoodReceiver
/// @notice Correctly implements the hook, so transfers to it succeed. Stands
///         in for something like a staking vault or a deposit contract that
///         was actually built to receive this token.
contract GoodReceiver is IERC223Recipient {
    address public lastFrom;
    uint256 public lastValue;
    bytes public lastData;
    uint256 public receivedCount;

    event TokensAccepted(address indexed from, uint256 value);

    function tokenReceived(address from, uint256 value, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        // A real receiver would check msg.sender == expectedTokenAddress here
        // if it only wanted to accept one specific token. Left open for this
        // demo so the same receiver can be tested against any ERC223Token.
        lastFrom = from;
        lastValue = value;
        lastData = data;
        receivedCount += 1;
        emit TokensAccepted(from, value);
        return 0x8943ec02; // the spec's magic value — see ERC223Token.ERC223_MAGIC_VALUE
    }
}
