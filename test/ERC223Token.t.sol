// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC223Token} from "../src/ERC223Token.sol";
import {GoodReceiver} from "../src/receivers/GoodReceiver.sol";
import {BadReceiver} from "../src/receivers/BadReceiver.sol";
import {RejectingReceiver} from "../src/receivers/RejectingReceiver.sol";

contract ERC223TokenTest is Test {
    ERC223Token internal token;
    GoodReceiver internal good;
    BadReceiver internal bad;
    RejectingReceiver internal rejecting;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob"); // a plain wallet, no code

    uint256 internal constant SUPPLY = 1_000_000e18;

    function setUp() public {
        vm.prank(alice);
        token = new ERC223Token("Test223", "T223", 18, SUPPLY);
        good = new GoodReceiver();
        bad = new BadReceiver();
        rejecting = new RejectingReceiver();
    }

    /*//////////////////////////////////////////////////////////////
                              HAPPY PATHS
    //////////////////////////////////////////////////////////////*/

    function test_Transfer_ToWallet_Succeeds() public {
        vm.prank(alice);
        bool ok = token.transfer(bob, 100e18);

        assertTrue(ok);
        assertEq(token.balanceOf(bob), 100e18);
        assertEq(token.balanceOf(alice), SUPPLY - 100e18);
    }

    function test_Transfer_ToContractWithHook_Succeeds() public {
        vm.prank(alice);
        token.transfer(address(good), 250e18);

        assertEq(token.balanceOf(address(good)), 250e18);
        assertEq(good.lastFrom(), alice);
        assertEq(good.lastValue(), 250e18);
        assertEq(good.receivedCount(), 1);
    }

    function test_TransferWithData_PassesDataToHook() public {
        bytes memory data = "invoice #42";
        vm.prank(alice);
        token.transfer(address(good), 10e18, data);

        assertEq(good.lastData(), data);
    }

    /// @notice The 2-arg transfer() passes hex"00000000" as _data, matching the
    ///          spec's reference implementation exactly (not truly empty bytes).
    function test_Transfer_EmitsEventWithData() public {
        vm.expectEmit(true, true, false, true);
        emit ERC223Token.Transfer(alice, bob, 50e18, hex"00000000");
        vm.prank(alice);
        token.transfer(bob, 50e18);
    }

    function test_ConstructorMintsSupplyToDeployerAndEmits() public {
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(alice), SUPPLY);
    }

    /// @notice decimals is a constructor parameter per the spec's reference
    ///         implementation, not a hardcoded value — a different token can
    ///         choose a different precision (e.g. 6, like USDC).
    function test_Constructor_DecimalsIsConfigurable() public {
        ERC223Token sixDecToken = new ERC223Token("SixDec", "SIX", 6, 1000);
        assertEq(sixDecToken.decimals(), 6);
        assertEq(token.decimals(), 18);
    }

    /// @notice Per spec, tokenReceived must return the magic value 0x8943ec02.
    function test_Hook_ReturnsSpecMagicValue() public {
        bytes4 ret = good.tokenReceived(alice, 1, "");
        assertEq(ret, token.ERC223_MAGIC_VALUE());
        assertEq(ret, bytes4(0x8943ec02));
    }

    /*//////////////////////////////////////////////////////////////
                     FAILURE CASES (the actual point)
    //////////////////////////////////////////////////////////////*/

    /// @notice THE core ERC-223 guarantee: a contract with no hook at all
    ///         rejects the transfer outright, instead of silently eating
    ///         the tokens the way plain ERC-20 would.
    function test_Transfer_ToContractWithoutHook_Reverts() public {
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(address(bad), 1e18);

        // and, critically, the balance never moved — no stuck tokens
        assertEq(token.balanceOf(address(bad)), 0);
        assertEq(token.balanceOf(alice), SUPPLY);
    }

    /// @notice A contract that HAS the hook but actively rejects is a
    ///         separate failure mode from "hook doesn't exist" — both must
    ///         revert, but for different reasons, and both must leave
    ///         balances untouched.
    function test_Transfer_ToRejectingReceiver_Reverts() public {
        vm.prank(alice);
        vm.expectRevert(RejectingReceiver.DepositsClosed.selector);
        token.transfer(address(rejecting), 1e18);

        assertEq(token.balanceOf(address(rejecting)), 0);
    }

    function test_Transfer_InsufficientBalance_Reverts() public {
        vm.prank(bob); // bob has 0 tokens
        vm.expectRevert(
            abi.encodeWithSelector(ERC223Token.InsufficientBalance.selector, bob, 0, 1e18)
        );
        token.transfer(alice, 1e18);
    }

    function test_Transfer_ToZeroAddress_Reverts() public {
        vm.prank(alice);
        vm.expectRevert(ERC223Token.TransferToZeroAddress.selector);
        token.transfer(address(0), 1e18);
    }

    /// @notice Rejected transfer to a bad receiver must leave the SENDER's
    ///         balance completely unchanged — proves the revert genuinely
    ///         unwinds the earlier balance update, not just the outer call.
    function test_FailedTransfer_LeavesSenderBalanceUntouched() public {
        uint256 before = token.balanceOf(alice);

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(address(bad), 999e18);

        assertEq(token.balanceOf(alice), before);
    }

    /*//////////////////////////////////////////////////////////////
                                 FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Transfer_ToWallet_NeverExceedsBalance(uint256 amount) public {
        amount = bound(amount, 0, SUPPLY);
        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(alice), SUPPLY - amount);
    }

    function testFuzz_Transfer_ToContractWithoutHook_AlwaysReverts(uint256 amount) public {
        amount = bound(amount, 1, SUPPLY);
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(address(bad), amount);
    }
}
