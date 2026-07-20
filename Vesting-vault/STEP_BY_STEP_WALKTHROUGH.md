# VestingVault — Complete Step-by-Step Demo Walkthrough

This document breaks down `step-by-step-demo.sh` from beginning to end. Each step is mapped to the actual implementation in `src/VestingVault.sol` and `test/mocks/MockERC20.sol`, explaining what happens on-chain, why it is implemented this way, and what you should see in Otterscan.

---

## 0. Prerequisites: Three Roles and Three Time Points

VestingVault is a linear vesting contract for **one token, one beneficiary, and one funding operation**. The demo uses three roles:

| Role | Anvil account | Private key (test only) | Responsibility |
|------|---------------|-------------------------|----------------|
| **Funder / Deployer** | `#0` `0xf39F...92266` | `0xac09...ff80` | Deploys the contract, funds it, and recovers mistakenly transferred tokens |
| **Beneficiary** | `#1` `0x7099...79C8` | `0x59c6...690d` | The only account allowed to call `claim()` |
| **Vault contract** | Assigned after deployment | — | Holds the tokens and releases them according to time |

The constructor permanently defines three time points that cannot be changed after deployment:

```solidity
// src/VestingVault.sol:62-67
uint64 public immutable start;   // vesting start time
uint64 public immutable cliff;   // = start + cliffDuration; 0 tokens claimable before this
uint64 public immutable end;     // = start + vestingDuration; 100% claimable after this
```

Demo configuration (`step-by-step-demo.sh:31-33`):

```bash
TOTAL_ALLOCATION="1000000000000000000000000"  # 1,000,000e18 = 1 million tokens
CLIFF_DURATION=$((30 * 24 * 60 * 60))          # 30 days
VESTING_DURATION=$((365 * 24 * 60 * 60))       # 365 days
```

---

## Environment Setup

Open three terminals and start one service in each:

**Terminal 1 — Anvil local node**

```bash
anvil --steps-tracing
```

`--steps-tracing` enables the `ots_*` namespace so that Otterscan can display internal transactions.

**Terminal 2 — Otterscan UI**

```bash
docker run --rm -p 5100:80 --name otterscan \
  -e ERIGON_URL="http://localhost:8545" \
  otterscan/otterscan:latest
```

Open `http://localhost:5100` in your browser.

**Terminal 3 — Run the demo**

```bash
cd <project-root>/Vesting-vault
DEPLOYER_KEY=0x<account0_key> BENEFICIARY_KEY=0x<account1_key> ./step-by-step-demo.sh
```

Copy the private keys from anvil's startup output (accounts #0 and #1).

---

## Step 1 — Deploy the MockERC20 Vesting Token

### Script

```bash
# step-by-step-demo.sh:42-47
TOKEN_ADDR=$(forge create test/mocks/MockERC20.sol:MockERC20 \
  --rpc-url "$RPC_URL" \
  --private-key "$DEPLOYER_KEY" \
  --broadcast \
  --json \
  --constructor-args "Demo Vested Token" "DVT" | jq -r '.deployedTo')
```

### Corresponding Contract

```solidity
// test/mocks/MockERC20.sol
contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
```

### What Happens

- The deployer deploys a standard OpenZeppelin ERC20 named `Demo Vested Token` (`DVT`).
- This mock exposes an **open** `mint()` function that anyone can call. It exists only for testing convenience; a production token should not be designed this way.
- The initial total supply is 0.

### What You See in Otterscan

A contract-creation transaction appears with `Contract creator = deployer` and `deployedTo = TOKEN_ADDR`.

---

## Step 2 — Mint 1 Million Tokens to the Deployer

### Script

```bash
# step-by-step-demo.sh:52-53
cast send "$TOKEN_ADDR" "mint(address,uint256)" "$DEPLOYER_ADDR" "$TOTAL_ALLOCATION" \
  --rpc-url "$RPC_URL" --private-key "$DEPLOYER_KEY" > /dev/null
```

### What Happens

The script calls `MockERC20.mint(deployer, 1_000_000e18)`. The deployer's wallet receives 1 million DVT, simulating a company receiving tokens that are ready to be vested.

### Selector Breakdown

The first 4 bytes of calldata are `keccak256("mint(address,uint256)")[:4] = 0x40c10f19`, followed by the deployer address (32 bytes) and the amount (32 bytes).

---

## Step 3 — Read the Current On-Chain Time

### Script

```bash
# step-by-step-demo.sh:58
START=$(cast block latest --rpc-url "$RPC_URL" --field timestamp)
```

### Why This Step Is Needed

`VestingVault.start` is an absolute timestamp passed to the constructor. The contract derives `cliff` and `end` by adding durations to it. The script reads the timestamp from Anvil's latest block so that `cliff = start + 30 days` and `end = start + 365 days` are relative to the current chain time.

**Important:** This is Anvil's actual on-chain time, not a `vm.warp` simulation. The later `evm_increaseTime` calls also modify this real Anvil clock.

---

## Step 4 — Deploy VestingVault

### Script

```bash
# step-by-step-demo.sh:63-68
VAULT_ADDR=$(forge create src/VestingVault.sol:VestingVault \
  --rpc-url "$RPC_URL" \
  --private-key "$DEPLOYER_KEY" \
  --broadcast \
  --json \
  --constructor-args "$TOKEN_ADDR" "$BENEFICIARY_ADDR" "$TOTAL_ALLOCATION" "$START" "$CLIFF_DURATION" "$VESTING_DURATION" | jq -r '.deployedTo')
```

### Corresponding Contract

```solidity
// src/VestingVault.sol:90-116
constructor(
    address token_,
    address beneficiary_,
    uint256 totalAllocation_,
    uint64 start_,
    uint64 cliffDuration_,
    uint64 vestingDuration_
) {
    if (token_ == address(0)) revert ZeroAddress();
    if (beneficiary_ == address(0)) revert ZeroAddress();
    if (totalAllocation_ == 0) revert ZeroAllocation();
    if (vestingDuration_ == 0) revert InvalidSchedule();
    if (cliffDuration_ > vestingDuration_) revert InvalidSchedule();
    if (vestingDuration_ > type(uint64).max - start_) revert ScheduleOverflow();

    token = IERC20(token_);
    beneficiary = beneficiary_;
    funder = msg.sender;                    // ← deployer is permanently fixed as funder
    totalAllocation = totalAllocation_;
    start = start_;
    cliff = start_ + cliffDuration_;
    end = start_ + vestingDuration_;
}
```

### Six Constructor Validations

1. `token_ != 0` — There is no asset to vest without a token.
2. `beneficiary_ != 0` — Sending tokens to the zero address would burn them.
3. `totalAllocation_ != 0` — A zero-allocation vault has no purpose.
4. `vestingDuration_ != 0` — A zero duration would cause division by zero.
5. `cliffDuration_ <= vestingDuration_` — The cliff cannot be longer than the entire vesting period.
6. `start_ + vestingDuration_` must not overflow `uint64`.

### Meaning of `immutable`

Seven variables (`token`, `beneficiary`, `funder`, `totalAllocation`, `start`, `cliff`, and `end`) are `immutable`: they can never be changed after deployment. Even the funder cannot modify them. This is the technical foundation of the contract's promise that it has no administrative back door.

---

## Step 5 — Approve and Fund

### Script

```bash
# step-by-step-demo.sh:78-81
cast send "$TOKEN_ADDR" "approve(address,uint256)" "$VAULT_ADDR" "$TOTAL_ALLOCATION" \
  --rpc-url "$RPC_URL" --private-key "$DEPLOYER_KEY" > /dev/null
cast send "$VAULT_ADDR" "fund(uint256)" "$TOTAL_ALLOCATION" \
  --rpc-url "$RPC_URL" --private-key "$DEPLOYER_KEY" > /dev/null
```

### Corresponding Contract

```solidity
// src/VestingVault.sol:127-140
function fund(uint256 amount) external nonReentrant {
    if (msg.sender != funder) revert NotFunder();
    if (funded) revert AlreadyFunded();
    if (amount != totalAllocation) revert IncorrectFundingAmount(totalAllocation, amount);

    funded = true;                                          // Effects first

    uint256 balanceBefore = token.balanceOf(address(this));
    token.safeTransferFrom(msg.sender, address(this), amount);
    uint256 received = token.balanceOf(address(this)) - balanceBefore;
    if (received != amount) revert FundingShortfall(amount, received);

    emit Funded(msg.sender, amount, block.timestamp);
}
```

### Two Transactions, Two Responsibilities

- **`approve`** is the standard ERC20 step: the deployer authorizes the vault to pull up to `TOTAL_ALLOCATION` tokens from the deployer's wallet.
- **`fund`** is the transaction that actually pulls the tokens into the vault.

### Four Guards

| Check | What it prevents |
|------|------------------|
| `msg.sender != funder` | Someone else trying to fund the vault |
| `funded` | Duplicate funding; funding is permanently one-time |
| `amount != totalAllocation` | Funding too much or too little |
| `received != amount` | Hidden shortfalls caused by fee-on-transfer or rebasing tokens |

The last check is especially important. Some ERC20 tokens (such as STA- or SafeMoon-style tokens) deduct a fee during transfers, so sending 100 tokens may result in only 98 arriving. The contract verifies the balance delta a second time and reverts, preventing the vault from becoming permanently underfunded.

### Checks-Effects-Interactions

Notice that `funded = true` is set **before** `safeTransferFrom`. This follows the Solidity Checks-Effects-Interactions pattern: update state first, then interact with an external contract to reduce reentrancy risk. The same pattern is used in `claim()`.

---

## Step 6 — Try to Claim Before the Cliff (Expected Revert)

### Script

```bash
# step-by-step-demo.sh:87-95
set +e
CLAIM_OUTPUT=$(cast send "$VAULT_ADDR" "claim()" --rpc-url "$RPC_URL" --private-key "$BENEFICIARY_KEY" 2>&1)
if echo "$CLAIM_OUTPUT" | grep -qi "NothingToClaim"; then
  echo "Reverted as expected: NothingToClaim"
fi
set -e
```

`set +e` temporarily disables Bash's “exit immediately on error” behavior because this step is intentionally expected to fail.

### Corresponding Contract

```solidity
// src/VestingVault.sol:170-181
function claim() external nonReentrant {
    if (msg.sender != beneficiary) revert NotBeneficiary();
    if (!funded) revert NotFundedYet();

    uint256 amount = claimableAmount();
    if (amount == 0) revert NothingToClaim();          // ← reverts here
    ...
}
```

Following the call into `claimableAmount()` and then `vestedAmount(now)`:

```solidity
// src/VestingVault.sol:150-155
function vestedAmount(uint64 timestamp) public view returns (uint256) {
    if (timestamp < cliff) return 0;                   // ← this branch is taken
    if (timestamp >= end) return totalAllocation;
    return totalAllocation * (timestamp - start) / (end - start);
}
```

### What This Proves

- The cliff gate works: before the cliff, the beneficiary cannot withdraw tokens.
- The contract uses a clear custom error, `NothingToClaim()`, which is cheaper than a string-based `require` and easier to assert in tests.

### What You Do Not See in Otterscan

The reverted transaction is not mined into a block, so it does not appear in Otterscan's transaction list.

---

## Step 7 — Advance Anvil Time by 60 Days

### Script

```bash
# step-by-step-demo.sh:99-101
ADVANCE_SECONDS=$((CLIFF_DURATION + 30 * 24 * 60 * 60))   # 30 + 30 = 60 days
cast rpc evm_increaseTime "$ADVANCE_SECONDS" --rpc-url "$RPC_URL" > /dev/null
cast rpc evm_mine --rpc-url "$RPC_URL" > /dev/null
```

### The Key Demo Technique

`vm.warp()` only works inside a Foundry script's simulated environment. It cannot change the clock of an external Anvil node. Anvil instead provides RPC methods that advance the real chain clock:

- `evm_increaseTime <seconds>` — tells Anvil to add the specified number of seconds to the next block's timestamp.
- `evm_mine` — immediately mines a new block, committing the new timestamp to the chain.

After these two commands, Anvil's on-chain time is `start + 60 days`: the cliff has passed, but the vesting period has not ended.

---

## Step 8 — Make the First Real Claim

### Script

```bash
# step-by-step-demo.sh:107-109
BEN_BALANCE_BEFORE=$(cast call "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$BENEFICIARY_ADDR" --rpc-url "$RPC_URL")
cast send "$VAULT_ADDR" "claim()" --rpc-url "$RPC_URL" --private-key "$BENEFICIARY_KEY" > /dev/null
BEN_BALANCE_AFTER=$(cast call "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$BENEFICIARY_ADDR" --rpc-url "$RPC_URL")
```

### Complete Contract Flow

```solidity
// src/VestingVault.sol:170-181
function claim() external nonReentrant {
    if (msg.sender != beneficiary) revert NotBeneficiary();
    if (!funded) revert NotFundedYet();

    uint256 amount = claimableAmount();
    if (amount == 0) revert NothingToClaim();

    claimed += amount;                        // Effects first
    token.safeTransfer(beneficiary, amount);  // Interactions second

    emit Claimed(beneficiary, amount, claimed, block.timestamp);
}
```

### How Much Does `claimableAmount()` Calculate?

```solidity
// src/VestingVault.sol:150-155
// The timestamp is past the cliff but before the end, so this branch is used:
return totalAllocation * (timestamp - start) / (end - start);
//   = 1_000_000e18 * 60 days / 365 days
//   ≈ 164,383.56e18
```

The beneficiary's token balance increases from 0 to approximately 164,383 tokens. `claimed` is updated to the same amount.

### Three Design Highlights

1. **There is no `recipient` parameter.** Structurally, the function cannot redirect funds to another wallet. This is structural anti-redirection: stronger than a runtime check because the code contains no such path.
2. **The CEI ordering is intentional.** `claimed += amount` executes before `safeTransfer`. Even if a token with a transfer hook attempts to reenter, `claimed` has already been updated and `claimableAmount()` will return 0 for that amount.
3. **The `nonReentrant` modifier is shared.** `claim()`, `fund()`, `sweepForeignToken()`, and `sweepExcess()` all use the same reentrancy lock, preventing cross-function reentrancy.

---

## Step 9 — Advance the Clock to the End of Vesting

### Script

```bash
# step-by-step-demo.sh:113-116
END_ADVANCE=$((VESTING_DURATION - CLIFF_DURATION - 30 * 24 * 60 * 60 + 1))
cast rpc evm_increaseTime "$END_ADVANCE" --rpc-url "$RPC_URL" > /dev/null
cast rpc evm_mine --rpc-url "$RPC_URL" > /dev/null
```

The calculation is `365 - 30 - 30 + 1 = 306 days`. Since the clock was already advanced by 60 days, Anvil is now at `start + 366 days`, exactly one second past `end`. The extra `+1` ensures that `timestamp >= end`.

---

## Step 10 — Make the Second Claim (Receive the Remainder)

### Script

```bash
# step-by-step-demo.sh:122
cast send "$VAULT_ADDR" "claim()" --rpc-url "$RPC_URL" --private-key "$BENEFICIARY_KEY" > /dev/null
```

### `vestedAmount` Branch Used This Time

```solidity
// src/VestingVault.sol:152
if (timestamp >= end) return totalAllocation;   // fully unlocked
```

Therefore:

```
amount = totalAllocation - claimed
       = 1_000_000e18 - 164_383e18
       ≈ 835_616e18
```

The beneficiary has now received exactly 1 million tokens in total. The vault's vesting-token balance is zero and `claimed == totalAllocation`.

---

## Step 11 — Try to Claim Again (Expected Revert)

### Script

```bash
# step-by-step-demo.sh:131-138
set +e
CLAIM_OUTPUT2=$(cast send "$VAULT_ADDR" "claim()" --rpc-url "$RPC_URL" --private-key "$BENEFICIARY_KEY" 2>&1)
if echo "$CLAIM_OUTPUT2" | grep -qi "NothingToClaim"; then
  echo "Reverted as expected: NothingToClaim (fully claimed already)"
fi
set -e
```

### Why It Reverts

```solidity
uint256 amount = claimableAmount();
// = vestedAmount(now) - claimed
// = totalAllocation - totalAllocation
// = 0
if (amount == 0) revert NothingToClaim();
```

This proves that the `claimed` accumulator works correctly: the vault cannot allow the beneficiary to claim more than the total allocation.

---

## Step 12 — Sweep a Foreign Token

This is one of the contract's most useful design features: **recovering another token that was accidentally sent to the vault**.

### Script

```bash
# step-by-step-demo.sh:143-157

# 12a. Deploy a stray token
FOREIGN_ADDR=$(forge create test/mocks/MockERC20.sol:MockERC20 ... | jq -r '.deployedTo')

# 12b. Mint 123 tokens to the vault (simulate an accidental transfer)
cast send "$FOREIGN_ADDR" "mint(address,uint256)" "$VAULT_ADDR" "$STRAY_AMOUNT" \
  --rpc-url "$RPC_URL" --private-key "$DEPLOYER_KEY" > /dev/null

# 12c. The funder calls sweepForeignToken to recover them
cast send "$VAULT_ADDR" "sweepForeignToken(address)" "$FOREIGN_ADDR" \
  --rpc-url "$RPC_URL" --private-key "$DEPLOYER_KEY" > /dev/null
```

### Corresponding Contract

```solidity
// src/VestingVault.sol:192-202
function sweepForeignToken(address foreignToken) external nonReentrant {
    if (msg.sender != funder) revert NotFunder();
    if (foreignToken == address(token)) revert CannotSweepVestedToken();   // ★

    uint256 amount = IERC20(foreignToken).balanceOf(address(this));
    if (amount == 0) revert NothingToSweep();

    IERC20(foreignToken).safeTransfer(funder, amount);       // always sends to funder

    emit Swept(foreignToken, funder, amount, block.timestamp);
}
```

### Two Structural Safeguards

1. **The `foreignToken == address(token)` check**
   The funder cannot use this function to touch the vesting token. Excess vesting tokens must be handled by `sweepExcess()`, which only sweeps `balance - (totalAllocation - claimed)`. Mathematically, it cannot touch the amount owed to the beneficiary.

2. **There is no `to` parameter; `safeTransfer(funder, ...)` is mandatory**
   This follows the same principle as `claim()` having no recipient parameter: structurally, the function cannot redirect funds to an attacker's wallet.

### Why `nonReentrant` Is Necessary Here

This function does not have a state variable that obviously needs protection (`amount` is a local variable). However, `nonReentrant` adds it to the contract's shared reentrancy lock. Imagine a malicious foreign token whose `transfer()` function contains a hook that calls back into `claim()` or `fund()` while the sweep is in progress. Without the shared lock, that cross-function reentrancy path would remain open.

### Why Otterscan Displays Selector `0xe0c050b4`

`keccak256("sweepForeignToken(address)")[:4] = 0xe0c050b4`. This is a project-specific function name, so it may not be recognized by Otterscan's built-in selector database like `fund` or `claim`. To understand the transaction, inspect **Input Data**: the first 4 bytes are the selector and the following 32 bytes contain the stray-token address. **Internal Transactions** should show a `Transfer(vault → funder, 123e18)` event emitted by the stray-token contract.

---

## Step 13 — Check the Final State

### Script

```bash
# step-by-step-demo.sh:162
FINAL_VAULT_BALANCE=$(cast call "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$VAULT_ADDR" --rpc-url "$RPC_URL")
echo "Vault vesting-token balance (should be 0, fully drained): $FINAL_VAULT_BALANCE"
```

This verifies that the vault's vesting-token balance is zero and all funds have been distributed or recovered as intended.

---

## The Five Transactions You See in Otterscan

Read from top to bottom for chronological order:

| # | Block | Method | From | Meaning |
|---|-------|--------|------|---------|
| 1 | 3 | (contract create) | Deployer | Deploy VestingVault |
| 2 | 5 | `fund` | Deployer | Deposit 1,000,000 tokens |
| 3 | 7 | `claim` | Beneficiary | First claim (~164,383 tokens) |
| 4 | 9 | `claim` | Beneficiary | Second claim (~835,616 tokens) |
| 5 | 12 | `0xe0c050b4` (`sweepForeignToken`) | Deployer | Recover 123 stray tokens |

**Notes:**

- The `approve` and `mint` transactions occur at the MockERC20 contract address, so they do not appear in the transaction list for the vault address.
- The failed claim before the cliff (Step 6) and the failed claim after everything was claimed (Step 11) reverted and were not mined into blocks, so Otterscan does not show them.
- The age displayed by Otterscan reflects the artificial time jumps from `evm_increaseTime`; real-world time did not actually pass by those amounts.

---

## Core Guarantees Protected by This Contract

| Guarantee | Mechanism |
|-----------|-----------|
| No rules can be changed after deployment | Seven `immutable` variables |
| The funder's deposit cannot be withdrawn, except for strictly defined excess | `sweepForeignToken` rejects the vesting token; `sweepExcess` only sweeps `balance - owed` |
| The beneficiary cannot claim early | `vestedAmount()` returns 0 when `timestamp < cliff` |
| The beneficiary cannot claim more than the total allocation | The `claimed` accumulator plus the `totalAllocation` cap in `vestedAmount` |
| Funds cannot be redirected to an attacker's wallet | `claim` and sweep functions have **no recipient parameter**; this is structural protection, not only a runtime check |
| Reentrancy attacks are blocked | CEI ordering plus a shared `nonReentrant` lock on the four mutating functions |
| Fee-on-transfer or rebasing tokens cannot silently underfund the vault | `fund` verifies the balance delta |
| Funding can happen only once | The `funded` boolean flag |

The five successful transactions and two expected reverts together exercise and verify each of these guarantees.

---

## Appendix: Common Unit Conversions

**ERC20 amounts:** The contract always uses integer base units. For an 18-decimal token, move the decimal point 18 places when displaying the amount:

```
1_000_000_000_000_000_000_000_000  → 1,000,000 tokens
       ↑ 24 digits                    ↑ 6 integer digits + 18 decimal digits
```

**Time in seconds:**

```
30 days  = 2,592,000
60 days  = 5,184,000
365 days = 31,536,000
```

**Anvil default accounts** (for testing only; never use these on a live network):

```
#0 (deployer/funder): 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
#1 (beneficiary):     0x70997970C51812dc3A010C7d01b50e0d17dc79C8

Keys are printed by anvil on startup — copy them from the terminal output.
```
