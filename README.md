# ERC-223 Build Task (Option D)

Setup:

    ./setup.sh

Or manually:

    forge install foundry-rs/forge-std
    forge test -vv

## Layout

- `src/ERC223Token.sol` — the token (matches the published spec's function
  signatures, including `tokenReceived` returning `bytes4` and `decimals` as
  a constructor param)
- `src/IERC223Recipient.sol` — the receiver hook interface
- `src/receivers/GoodReceiver.sol` — implements the hook, returns the magic
  value, accepts transfers
- `src/receivers/BadReceiver.sol` — no hook at all, transfers to it revert
- `src/receivers/RejectingReceiver.sol` — has the hook but always reverts
- `test/ERC223Token.t.sol` — 14 tests (12 unit + 2 fuzz)
- `DESIGN_NOTE.md` — the required design note, including the spec-fidelity
  correction made after checking the draft against the actual EIP-223 text
