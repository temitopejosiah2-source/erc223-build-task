# Interacting with ERC223Token — Live Demo Walkthrough

You don't need a testnet for this — a local chain (Anvil, ships with
Foundry) is faster, free, and works with no internet during your defense.

## Setup

Terminal A - start the local chain and leave it running: anvil

Terminal B - deploy everything in one shot:
forge script script/Deploy.s.sol --broadcast --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

Copy the four printed addresses.

## The demo script

1. Check starting balance:
cast call $TOKEN "balanceOf(address)(uint256)" $(cast wallet address --private-key $KEY) --rpc-url $RPC

2. Transfer to a plain wallet - succeeds:
cast send $TOKEN "transfer(address,uint256)" $WALLET 1000000000000000000 --private-key $KEY --rpc-url $RPC
cast call $TOKEN "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC

3. Transfer to GoodReceiver - succeeds, hook fires:
cast send $TOKEN "transfer(address,uint256)" $GOOD 2000000000000000000 --private-key $KEY --rpc-url $RPC
cast call $GOOD "lastValue()(uint256)" --rpc-url $RPC
cast call $GOOD "receivedCount()(uint256)" --rpc-url $RPC

4. Transfer to BadReceiver - MUST revert (the key demo moment):
cast send $TOKEN "transfer(address,uint256)" $BAD 1000000000000000000 --private-key $KEY --rpc-url $RPC
cast call $TOKEN "balanceOf(address)(uint256)" $BAD --rpc-url $RPC
Should still read 0.

5. (Optional) Transfer to RejectingReceiver - also reverts, different reason:
cast send $TOKEN "transfer(address,uint256)" $REJECTING 1000000000000000000 --private-key $KEY --rpc-url $RPC

## If asked to modify something live

"Make RejectingReceiver accept transfers": edit src/receivers/RejectingReceiver.sol,
change the revert to return 0x8943ec02, save, rerun forge test.

"Insufficient balance case": rerun step 2 with a huge number, get InsufficientBalance
error. Point to the check in _transfer() in ERC223Token.sol.

## Fallback

If anvil isn't running or a command hangs, just restart anvil in Terminal A
and rerun the deploy command in Terminal B.
