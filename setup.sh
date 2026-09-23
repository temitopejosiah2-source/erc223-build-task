#!/usr/bin/env bash
set -e
if ! command -v forge >/dev/null 2>&1; then
  echo "Foundry not found. Install: curl -L https://foundry.paradigm.xyz | bash"
  echo "then restart your terminal and run: foundryup"
  exit 1
fi
[ -d .git ] || git init -q
forge install foundry-rs/forge-std
forge test -vv
