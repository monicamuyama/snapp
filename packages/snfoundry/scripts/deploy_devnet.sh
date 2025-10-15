#!/usr/bin/env bash
set -euo pipefail

echo "Helper: start a local Starknet devnet and deploy sacco_core + paymaster (edit to match your toolchain)"

# Example steps (uncomment and adapt to your environment):
# 1) start a local devnet (starknet-devnet, docker image, or scaffold-stark dev server)
#    starknet-devnet --port 5050 &
#    DEVNET_PID=$!

# 2) compile contracts (adjust to your build tool)
#    cargo run --bin snforge-compile -- contracts/src/*.cairo

# 3) deploy contracts (replace with your deployment command; examples below are placeholders)
#    npx @shardlabs/scaffold-starknet deploy --network local --contract contracts/src/sacco_core.cairo --constructor-args <owner>
#    npx @shardlabs/scaffold-starknet deploy --network local --contract contracts/src/paymaster.cairo --constructor-args <owner>

echo "TODO: replace placeholder commands with your project's compile & deploy steps."
echo "When done, you can tail the devnet logs or run tests against the deployed addresses."

# Optional: wait for user to stop
# read -p "Press ENTER to stop devnet and exit" _
# kill $DEVNET_PID || true
