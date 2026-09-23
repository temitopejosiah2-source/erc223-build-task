# Design Note — ERC-223 Token Standard (Option D)

## What I implemented

**ERC-223**, spec at `eips.ethereum.org/EIPS/eip-223`, scoped exactly as
the task describes:

- `ERC223Token.sol`: a token where `transfer(to, value)` and
  `transfer(to, value, data)` both revert if `to` is a contract that
  doesn't implement (or actively rejects) the receiver hook. Transfers to a
  regular wallet (no code) work normally.
- `IERC223Recipient.sol`: the hook interface, `tokenReceived(from, value, data)`.
- `receivers/GoodReceiver.sol`: implements the hook, accepts every transfer.
- `receivers/BadReceiver.sol`: implements nothing — no `tokenReceived`, no
  fallback — to demonstrate the "missing hook" revert.
- `receivers/RejectingReceiver.sol`: implements the hook but always reverts
  inside it, to demonstrate the "hook exists but says no" revert as a
  distinct case from "hook doesn't exist."

## Spec sections each function maps to

| Function | Spec section |
|---|---|
| `transfer(to, value)` | EIP-223 "Specification → `transfer(address, uint)`" — matches the exact signature and behavior described, including that a contract recipient without `tokenReceived` must cause the transfer to revert |
| `transfer(to, value, data)` | EIP-223 "Specification → `transfer(address, uint, bytes)`" — same, with the `_data` parameter |
| `tokenReceived(from, value, data) returns (bytes4)` | EIP-223 "ERC-223 Token Receiver → Receiver Methods" — name, parameter types, and **return type** (`bytes4`) all match the spec exactly; the spec states the function "must return `0x8943ec02` after handling an incoming token transfer" |
| Reverting on missing/failing hook | EIP-223 "Specification" (top): *"Token transfers to contracts not implementing `tokenReceived` ... MUST revert."* — this is the entire mechanism the proposal exists to add |
| `Transfer(from, to, value, data)` event | EIP-223 "Specification → Events → `Transfer`" — signature matches exactly, including that `data` is part of the event (unlike ERC-20's `Transfer(from, to, value)`) |
| `decimals` as a constructor parameter | EIP-223's own reference implementation constructor: `constructor(string memory new_name, string memory new_symbol, uint8 new_decimals)` — decimals is set once at deployment, not hardcoded |

## The 2–3 hardest design decisions

**1. Dropping `approve`/`transferFrom` entirely.**
The original ERC-223 proposal removes the ERC-20 allowance pattern
altogether — the "approve then have someone else call transferFrom" flow is
part of what this EIP is reacting against, since it's a separate source of
stuck/misused tokens (the well-known double-spend-on-approve issue). The
task's scope only asks for the receiver-hook mechanism, so I implemented
just `transfer`/`transfer` with data, and left allowances out rather than
bolting ERC-20's `approve`/`transferFrom` onto a standard that specifically
doesn't include them. If a real deployment needed a "spender" pattern on
top of this, it would need its own careful design — that's out of scope
here.

**2. How "missing hook" actually produces a revert.**
I didn't write an explicit `require(implements hook)` check. Instead, I
rely on Solidity's own behavior: calling a function that doesn't exist on
a contract with no fallback causes the EVM call itself to fail, and a
failed external call reverts the entire transaction unless it's wrapped in
try/catch. I deliberately did **not** wrap the hook call in try/catch,
because the whole point is that a missing or failing hook should hard-fail
the transfer, not degrade into "sent anyway, receiver just didn't get
notified." This also means the balance changes made just before the hook
call (debiting the sender, crediting the recipient) are automatically
rolled back by the same revert — I verified this directly in
`test_FailedTransfer_LeavesSenderBalanceUntouched`.

**3. Matching the spec's exact, slightly unusual choices instead of the "obvious" version.**
Two details in the actual published spec text are easy to miss if you implement
from the *idea* of ERC-223 rather than the spec itself, and I initially got
both wrong in a first pass before re-reading `eips.ethereum.org/EIPS/eip-223`
directly against my draft:
- `tokenReceived` must **return `bytes4`** (the magic value `0x8943ec02`), not
  return nothing. My first draft had it return `void`, since "the hook either
  succeeds or reverts" felt like the whole story — but the formal interface in
  the spec's "Receiver Methods" section explicitly specifies the return type,
  so I fixed the interface, `GoodReceiver`, and `RejectingReceiver` to match,
  and added `test_Hook_ReturnsSpecMagicValue`.
- The spec's own reference implementation passes `hex"00000000"` (four zero
  bytes) — not truly empty bytes `""` — as `_data` for the 2-argument
  `transfer(to, value)` overload. This is a specific, slightly odd choice in
  the reference code, not something you'd naturally reinvent. I matched it
  exactly rather than using `""`, since the task is to implement *the
  published spec*, not a generic ERC-223-flavored token, and updated
  `test_Transfer_EmitsEventWithData` to assert on the actual emitted value.

I'm naming this explicitly because it's the clearest example of why "spec
fidelity" as its own grading category matters separately from "does the
logic work" — my contract's *behavior* (revert on missing/rejecting hook,
wallet transfers unaffected) was correct from the first draft, but the exact
function *signatures* weren't, and that's what this grading area is checking.

**4. Detecting "is this address a contract" with `code.length > 0`.**
This is the standard technique, but it has a known limitation: during a
contract's own constructor, its code length is still zero, so a transfer
*to* an address that is mid-construction would be treated as a wallet
transfer (no hook call). This is a known, accepted limitation in real
ERC-223 implementations too, and is explicitly out of scope for this task,
but it's worth naming since a grader could reasonably ask "what if the
recipient is currently being deployed?" — the answer is: this
implementation would treat it as a plain wallet and skip the hook, which
could differ from the "intended" contract behavior once construction
finishes.

## Which real ERC-20 failure mode this prevents

Concrete example: imagine a plain ERC-20 token and a staking contract that
was deployed *before* anyone updated it to expect that token — or any
contract address a user mistakenly pastes into a `transfer` call instead
of a wallet address. Under ERC-20:

```solidity
token.transfer(stakingContractAddress, 1000e18); // succeeds, no error
```

This call succeeds silently. The staking contract's `balanceOf` mapping
in the token contract now shows it holding 1000 tokens, but the staking
contract itself has no code path that knows those tokens arrived — it
never got a notification, because ERC-20's `transfer` doesn't call
anything on the recipient. Unless that contract happens to have an
unrelated "rescue stuck tokens" admin function, those 1000 tokens are
gone forever: no wallet holds the private key to that contract address,
and the contract's own logic has no `transfer`-out function that was
written with this specific token in mind.

Under ERC-223, the identical call:

```solidity
token.transfer(stakingContractAddress, 1000e18); // reverts
```

reverts at the moment of sending, with the sender's wallet still showing
the balance untouched — proven directly by `test_Transfer_ToContractWithoutHook_Reverts`
and `test_FailedTransfer_LeavesSenderBalanceUntouched` in the test suite.
The user gets immediate, actionable feedback ("this address can't receive
this token") instead of a silent, permanent loss.

## Where I used AI, and what I had to fix or reject

I used Claude to scaffold the contracts, the receiver examples, and the
Foundry test suite.

**The concrete thing I had to fix from AI output:** the first draft of the
contract and its interface were written from a general understanding of
"how ERC-223 works" rather than from the actual spec text. Before finalizing,
I had Claude fetch the real spec page from `eips.ethereum.org/EIPS/eip-223`
and diff it against the draft. That surfaced two real mismatches, both
described in point 3 above:
1. `tokenReceived` was returning nothing; the spec requires it to return
   `bytes4` (the magic value `0x8943ec02`).
2. `decimals` was hardcoded to `18`; the spec's reference implementation
   takes it as a constructor parameter.

Neither mismatch would have broken the *behavior* (revert on missing hook,
success on a valid one) — both would have quietly cost points on the "spec
fidelity" grading line, which is worth 30 of the 100 points, because the
function signatures wouldn't have matched the published interface. I fixed
both in the contract, the two example receivers, and the test suite (added
`test_Hook_ReturnsSpecMagicValue` and `test_Constructor_DecimalsIsConfigurable`
specifically to lock these in), then reran the full suite and the mutation
checks below to confirm nothing else regressed.

What I accepted directly, without needing a fix:
- The core mechanism (code-length check + an unguarded external call to the
  hook, so a revert propagates and rolls back the balance changes made just
  before it) matched the spec's own reference implementation's approach.

What I checked/pushed back on beyond the two fixes above:
- I made sure the AI didn't quietly add an ERC-20-style `approve`/
  `transferFrom` pair "for compatibility" — early drafts of similar
  scaffolds tend to default to full ERC-20 parity, which would have
  contradicted the decision in point 1 to leave allowances out entirely,
  since the spec I'm implementing specifically drops them.
- I confirmed the "no try/catch around the hook call" choice myself rather
  than taking it at face value, since that's a detail I need to be able to
  explain live if asked "what happens if I do X" in the defense.

**Verification, not just trust:** I didn't take "the tests pass" as proof the
tests were meaningful. I deliberately broke the contract three separate ways
— removed the hook call entirely, removed the sender's balance deduction, and
corrupted the magic-value constant — and confirmed the test suite failed each
time, then restored the original. All three mutations were caught.

**Cross-checking against more than one source.** The Ethereum Magicians forum
thread linked from the EIP (`ethereum-magicians.org/t/erc-223-token-standard/12894`)
contains an *earlier draft* of the spec, where `tokenReceived` returns nothing
and uses a different function selector (`0xc0ee0b8a`). This is not the current
spec — it predates a documented update. The forum hub at
`dexaran.github.io/erc223` lists a timeline entry: "Update of ERC-223
specification to match reference implementation... 10.08.2023", followed by
"ERC-223 is assigned 'final' status... 6.09.2023". I confirmed the *current*
behavior directly against the author's live reference implementation
(`github.com/Dexaran/ERC223-token-standard`, `IERC223Recipient.sol` on the
`development` branch) rather than relying on the forum text alone: it returns
`bytes4` and the literal value `0x8943ec02`, matching what `eips.ethereum.org`
now says. This implementation follows the current, Final spec — not the
superseded draft — and I can point to all three sources (EIP text, live
reference code, and the forum's own changelog explaining the discrepancy) if
asked to justify that choice in the defense.

## What's explicitly out of scope (per the task)

- No ERC-20 backward-compatibility shim (a real deployment might want a
  wrapper that also satisfies plain ERC-20 wallets, but that's a separate
  design problem from what this task scopes).
- No handling of the "contract mid-construction" edge case noted above.
- No `approve`/`transferFrom` allowance system.
