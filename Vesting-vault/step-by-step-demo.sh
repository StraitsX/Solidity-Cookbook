#!/usr/bin/env bash
# =============================================================================
# step-by-step-demo.sh
#
# Runs the full VestingVault lifecycle as REAL broadcast transactions against a
# local anvil chain, advancing time with anvil's own clock (evm_increaseTime /
# evm_mine) instead of Foundry's vm.warp (which only works inside script
# simulation, not against a live node).
#
# Usage:
#   1. In one terminal:  anvil
#   2. In another terminal, from the project root: ./step-by-step-demo.sh
#
# Everything below uses anvil's pre-funded test accounts. The script does NOT
# embed any private keys or mnemonics — you must supply them via environment
# variables after reading them from anvil's startup output.
#
# Usage:
#   1. In one terminal:  anvil
#   2. Copy the private keys from anvil's output, then run:
#      DEPLOYER_KEY=0x<account0_key> BENEFICIARY_KEY=0x<account1_key> ./step-by-step-demo.sh
#
# The accounts must already hold ETH on the target chain (anvil pre-funds its
# default accounts with 10000 ETH each). These are NOT real funds and NOT
# secret — never reuse them on a real network.
# =============================================================================

set -euo pipefail

RPC_URL="http://localhost:8545"

# Safety gate: prevent accidental execution against a real network.
CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null || echo "unknown")
if [ "$CHAIN_ID" != "31337" ]; then
  echo "ERROR: This script is for local Anvil only (chain_id=31337). Got: $CHAIN_ID" >&2
  exit 1
fi

# Require keys from the environment — no embedded secrets.
if [[ -z "${DEPLOYER_KEY:-}" || -z "${BENEFICIARY_KEY:-}" ]]; then
  echo "ERROR: DEPLOYER_KEY and BENEFICIARY_KEY must be set." >&2
  echo "" >&2
  echo "Start anvil, then copy the private keys from its output:" >&2
  echo "  DEPLOYER_KEY=0x<key0> BENEFICIARY_KEY=0x<key1> ./step-by-step-demo.sh" >&2
  exit 1
fi

DEPLOYER_ADDR=$(cast wallet address --private-key "$DEPLOYER_KEY")

# anvil default account #1 — used as beneficiary
BENEFICIARY_ADDR=$(cast wallet address --private-key "$BENEFICIARY_KEY")

TOTAL_ALLOCATION="1000000000000000000000000"  # 1,000,000e18
CLIFF_DURATION=$((30 * 24 * 60 * 60))          # 30 days in seconds
VESTING_DURATION=$((365 * 24 * 60 * 60))       # 365 days in seconds

echo "================================================================"
echo " Deployer/Funder:  $DEPLOYER_ADDR"
echo " Beneficiary:      $BENEFICIARY_ADDR"
echo "================================================================"

echo ""
echo "--- Step 1: Deploy MockERC20 vesting token ---"
TOKEN_ADDR=$(forge create test/mocks/MockERC20.sol:MockERC20 \
  --rpc-url "$RPC_URL" \
  --private-key "$DEPLOYER_KEY" \
  --broadcast \
  --json \
  --constructor-args "Demo Vested Token" "DVT" | jq -r '.deployedTo')
echo "Token deployed at: $TOKEN_ADDR"

echo ""
echo "--- Step 2: Mint the total allocation to the deployer ---"
cast send "$TOKEN_ADDR" "mint(address,uint256)" "$DEPLOYER_ADDR" "$TOTAL_ALLOCATION" \
  --rpc-url "$RPC_URL" --private-key "$DEPLOYER_KEY" > /dev/null
echo "Minted $TOTAL_ALLOCATION to deployer."

echo ""
echo "--- Step 3: Read the current chain timestamp (this is anvil's REAL clock) ---"
START=$(cast block latest --rpc-url "$RPC_URL" --field timestamp)
echo "Chain timestamp (start): $START"

echo ""
echo "--- Step 4: Deploy VestingVault ---"
VAULT_ADDR=$(forge create src/VestingVault.sol:VestingVault \
  --rpc-url "$RPC_URL" \
  --private-key "$DEPLOYER_KEY" \
  --broadcast \
  --json \
  --constructor-args "$TOKEN_ADDR" "$BENEFICIARY_ADDR" "$TOTAL_ALLOCATION" "$START" "$CLIFF_DURATION" "$VESTING_DURATION" | jq -r '.deployedTo')
echo "VestingVault deployed at: $VAULT_ADDR"

CLIFF=$(cast call "$VAULT_ADDR" "cliff()(uint64)" --rpc-url "$RPC_URL")
END=$(cast call "$VAULT_ADDR" "end()(uint64)" --rpc-url "$RPC_URL")
echo "  cliff: $CLIFF"
echo "  end:   $END"

echo ""
echo "--- Step 5: Approve + fund the vault (real on-chain transfer) ---"
cast send "$TOKEN_ADDR" "approve(address,uint256)" "$VAULT_ADDR" "$TOTAL_ALLOCATION" \
  --rpc-url "$RPC_URL" --private-key "$DEPLOYER_KEY" > /dev/null
cast send "$VAULT_ADDR" "fund(uint256)" "$TOTAL_ALLOCATION" \
  --rpc-url "$RPC_URL" --private-key "$DEPLOYER_KEY" > /dev/null
VAULT_BALANCE=$(cast call "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$VAULT_ADDR" --rpc-url "$RPC_URL")
echo "Vault funded. Vault token balance: $VAULT_BALANCE"

echo ""
echo "--- Step 6: Try to claim BEFORE the cliff (should revert — proves the cliff gate works) ---"
set +e
CLAIM_OUTPUT=$(cast send "$VAULT_ADDR" "claim()" --rpc-url "$RPC_URL" --private-key "$BENEFICIARY_KEY" 2>&1)
if echo "$CLAIM_OUTPUT" | grep -qi "NothingToClaim"; then
  echo "Reverted as expected: NothingToClaim (nothing vested yet, still before the cliff)"
else
  echo "UNEXPECTED: claim() did not revert with NothingToClaim"
  echo "$CLAIM_OUTPUT"
fi
set -e

echo ""
echo "--- Step 7: Advance anvil's REAL clock by cliff + 30 days ---"
ADVANCE_SECONDS=$((CLIFF_DURATION + 30 * 24 * 60 * 60))
cast rpc evm_increaseTime "$ADVANCE_SECONDS" --rpc-url "$RPC_URL" > /dev/null
cast rpc evm_mine --rpc-url "$RPC_URL" > /dev/null
NEW_TS=$(cast block latest --rpc-url "$RPC_URL" --field timestamp)
echo "Chain timestamp advanced to: $NEW_TS (advanced by $ADVANCE_SECONDS seconds)"

echo ""
echo "--- Step 8: First real claim() — should succeed now, transferring the linearly vested portion ---"
BEN_BALANCE_BEFORE=$(cast call "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$BENEFICIARY_ADDR" --rpc-url "$RPC_URL")
cast send "$VAULT_ADDR" "claim()" --rpc-url "$RPC_URL" --private-key "$BENEFICIARY_KEY" > /dev/null
BEN_BALANCE_AFTER=$(cast call "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$BENEFICIARY_ADDR" --rpc-url "$RPC_URL")
echo "Beneficiary balance: $BEN_BALANCE_BEFORE -> $BEN_BALANCE_AFTER"

echo ""
echo "--- Step 9: Advance the clock all the way to (and past) 'end' ---"
END_ADVANCE=$((VESTING_DURATION - CLIFF_DURATION - 30 * 24 * 60 * 60 + 1))
cast rpc evm_increaseTime "$END_ADVANCE" --rpc-url "$RPC_URL" > /dev/null
cast rpc evm_mine --rpc-url "$RPC_URL" > /dev/null
NEW_TS2=$(cast block latest --rpc-url "$RPC_URL" --field timestamp)
echo "Chain timestamp advanced to: $NEW_TS2"

echo ""
echo "--- Step 10: Second real claim() — should transfer ALL remaining tokens ---"
cast send "$VAULT_ADDR" "claim()" --rpc-url "$RPC_URL" --private-key "$BENEFICIARY_KEY" > /dev/null
CLAIMED=$(cast call "$VAULT_ADDR" "claimed()(uint256)" --rpc-url "$RPC_URL" | awk '{print $1}')
BEN_FINAL=$(cast call "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$BENEFICIARY_ADDR" --rpc-url "$RPC_URL" | awk '{print $1}')
echo "Total claimed (contract state): $CLAIMED"
echo "Beneficiary final balance:      $BEN_FINAL"
echo "Matches totalAllocation ($TOTAL_ALLOCATION)? $([ "$CLAIMED" = "$TOTAL_ALLOCATION" ] && echo yes || echo NO)"

echo ""
echo "--- Step 11: Try to claim again (should revert — nothing left) ---"
set +e
CLAIM_OUTPUT2=$(cast send "$VAULT_ADDR" "claim()" --rpc-url "$RPC_URL" --private-key "$BENEFICIARY_KEY" 2>&1)
if echo "$CLAIM_OUTPUT2" | grep -qi "NothingToClaim"; then
  echo "Reverted as expected: NothingToClaim (fully claimed already)"
else
  echo "UNEXPECTED: claim() did not revert with NothingToClaim"
  echo "$CLAIM_OUTPUT2"
fi
set -e

echo ""
echo "--- Step 12: Demonstrate sweepForeignToken — simulate a stray transfer, then recover it ---"
FOREIGN_ADDR=$(forge create test/mocks/MockERC20.sol:MockERC20 \
  --rpc-url "$RPC_URL" \
  --private-key "$DEPLOYER_KEY" \
  --broadcast \
  --json \
  --constructor-args "Stray" "STRY" | jq -r '.deployedTo')
STRAY_AMOUNT="123000000000000000000" # 123e18
cast send "$FOREIGN_ADDR" "mint(address,uint256)" "$VAULT_ADDR" "$STRAY_AMOUNT" \
  --rpc-url "$RPC_URL" --private-key "$DEPLOYER_KEY" > /dev/null
echo "Simulated a stray foreign-token transfer of $STRAY_AMOUNT into the vault."

FUNDER_BEFORE=$(cast call "$FOREIGN_ADDR" "balanceOf(address)(uint256)" "$DEPLOYER_ADDR" --rpc-url "$RPC_URL")
cast send "$VAULT_ADDR" "sweepForeignToken(address)" "$FOREIGN_ADDR" \
  --rpc-url "$RPC_URL" --private-key "$DEPLOYER_KEY" > /dev/null
FUNDER_AFTER=$(cast call "$FOREIGN_ADDR" "balanceOf(address)(uint256)" "$DEPLOYER_ADDR" --rpc-url "$RPC_URL")
echo "Funder foreign-token balance: $FUNDER_BEFORE -> $FUNDER_AFTER"

echo ""
echo "--- Step 13: Final vault state ---"
FINAL_VAULT_BALANCE=$(cast call "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$VAULT_ADDR" --rpc-url "$RPC_URL")
echo "Vault vesting-token balance (should be 0, fully drained): $FINAL_VAULT_BALANCE"

echo ""
echo "================================================================"
echo " Demo complete. Every step above was a REAL broadcast transaction"
echo " against your local anvil chain (not a simulation)."
echo "================================================================"
