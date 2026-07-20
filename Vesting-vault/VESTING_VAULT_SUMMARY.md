# VestingVault — Concept Summary

A quick-reference walkthrough of the VestingVault contract: what it is, how the pieces fit together, and the design choices behind it.

---

## 1. Three Main Actors

```
┌────────────────┐    ┌────────────────┐    ┌────────────────┐
│ Token Contract │    │ VestingVault   │    │ Wallet         │
│ (Ledger)       │    │ (Safe / Box)   │    │ (addr + key)   │
│                │    │                │    │                │
│ - DVT: main    │    │ - Lockup logic │    │ - Funder       │
│ - STRAY: rogue │    │ - 1 beneficiary│    │ - Beneficiary  │
│                │    │ - 1 token      │    │                │
└────────────────┘    └────────────────┘    └────────────────┘
```

- **Token contract**: the *ledger*. Balances live inside its `_balances` mapping.
- **VestingVault**: the *safe*. Holds tokens and releases them to a specific beneficiary over time.
- **Wallet**: just an *address + private key*. Wallets don't store tokens — the token contract's ledger does.

**Key distinction that trips people up**:
- Tokens are **not** stored in wallets. They live in the token contract's storage.
- A wallet is just the "key that proves you can move a specific row in the ledger."
- Contracts also have addresses, so contracts can also "hold" tokens (i.e., they appear as balance rows in the token contract).

---

## 2. Four Things That Are Immutable

Once deployed, the VestingVault **cannot change** any of these:

```solidity
IERC20  immutable token;              // Only vests this one token
address immutable beneficiary;        // Only this address can claim
address immutable funder;             // Only this address can fund/sweep
uint256 immutable totalAllocation;    // Total amount is fixed
uint64  immutable start / cliff / end;  // Schedule is fixed
```

**Implications**:
- One vault = one token × one beneficiary × one schedule.
- To vest for multiple people, deploy multiple vaults.
- No admin backdoor. No upgrade path. No mutation whatsoever.

---

## 3. Time Schedule: Cliff + Linear Vesting

```
Timeline:

  |─────────|─────────────────────────|
  start    cliff                     end
   0%       0%                      100%

  Before cliff : 0 tokens claimable  (cliff gate)
  cliff to end : linear release
  After end    : 100% claimable
```

**Core formula** (`vestedAmount`):

```solidity
if (timestamp < cliff) return 0;                              // Cliff gate
if (timestamp >= end)  return totalAllocation;                // Fully vested
return totalAllocation * (timestamp - start) / (end - start); // Linear
```

**Demo values**: `start = now`, `cliff = start + 30 days`, `end = start + 365 days`, `totalAllocation = 1,000,000`
- Before day 30: 0
- Day 60: ~164,383 tokens (60/365 ≈ 16.4%)
- After day 365: full 1,000,000

---

## 4. Four Key Functions

### `fund(amount)` — Load tokens (one-shot)

- **Who can call**: only the funder
- **How many times**: **once** (`funded` bool locks it forever)
- **Amount**: must **exactly match** `totalAllocation`
- **Key defenses**:
  - Uses balance-delta verification to detect fee-on-transfer / rebase tokens.
  - CEI order: `funded = true` written *before* the external transfer.

### `claim()` — Withdraw tokens (pull-based)

- **Who can call**: only the beneficiary
- **How many times**: unlimited (each call transfers `vested - claimed`)
- **No recipient parameter**: tokens always go to the beneficiary — structural anti-redirect.
- **Key defenses**:
  - `claimed += amount` updated *before* the transfer — CEI order.
  - `nonReentrant` guard against reentrancy.
  - Before cliff → `vestedAmount = 0` → reverts with `NothingToClaim`.

### `sweepForeignToken(token)` — Rescue misdirected tokens

- **Who can call**: only the funder
- **Protection**: cannot pass the main vesting token (`revert CannotSweepVestedToken`).
- **Fixed recipient**: `safeTransfer(funder, amount)` — no `to` parameter, tokens always go back to funder.
- **Purpose**: recover any ERC20 accidentally transferred into the vault (wrong address paste, airdrop dust, etc.).

### `sweepExcess()` — Sweep excess of the main token

- **Who can call**: only the funder
- **Only sweeps the surplus**: `excess = balance - (totalAllocation - claimed)`
- **Meaning**: funder cannot touch what the beneficiary is owed; can only recover accidental overfunding.

---

## 5. Pull-Based Design — This Is the Core Idea

**Nothing is automatic**:
- When time passes, the contract does nothing on its own.
- The beneficiary must **actively send a transaction** to call `claim()`.
- The funder only acts at deploy + fund time (and again only if a sweep is needed).

**Why pull-based**:
- Ethereum has **no cron jobs**. Nothing runs automatically on-chain.
- Pull saves gas (the beneficiary pays only when they want to withdraw).
- Pull is safer (the beneficiary controls the timing).
- The contract stays tiny — the whole file is ~225 lines.

**No caller = nothing happens.** This is a fundamental rule of Solidity.

---

## 6. The 5 On-Chain Transactions in the Demo

```
On the Vault's Otterscan page:

Block 3:  Contract Create → Deploy Vault
Block 5:  fund              → Funder loads 1,000,000 tokens
Block 7:  claim             → Beneficiary withdraws ~164,383 (day 60)
Block 9:  claim             → Beneficiary withdraws ~835,617 (day 366)
Block 12: sweepForeignToken → Funder recovers 123 stray tokens
```

**Not visible on the Vault page**:
- Failed pre-cliff claim (reverted, never mined).
- Failed post-fully-claimed claim (reverted, never mined).
- `approve` (shows up on the DVT contract page, not the vault).
- `mint` (shows up on the DVT / STRAY contract pages).

---

## 7. Three Mock Files

| File | Role | Used in Demo? |
|------|------|--------------|
| `MockERC20` | Main vesting token (DVT) | Yes — deployed at Step 1 |
| `MockERC20Foreign` | Stray token accidentally sent to vault | Yes — deployed at Step 12 |
| `MockFeeOnTransferERC20` | Malicious token that skims a fee on transfer | No — used only by the Foundry test suite |

---

## 8. Five Security Guarantees and How They're Enforced

| Guarantee | Mechanism |
|-----------|-----------|
| Rules cannot change post-deploy | Seven `immutable` variables |
| Funder cannot claw back what's owed to beneficiary | `sweepForeignToken` blocks main token + `sweepExcess` only sweeps surplus |
| Beneficiary cannot claim early | `vestedAmount` returns 0 before cliff |
| Beneficiary cannot exceed total allocation | `claimed` counter + `vestedAmount` capped at `totalAllocation` |
| Tokens cannot be redirected to an attacker | Neither `claim` nor sweep functions have a recipient parameter |
| Reentrancy | CEI ordering + `nonReentrant` guard |
| Fee-on-transfer shortfall | `fund` uses balance-delta verification |
| Fund can only happen once | `funded` bool flag |

---

## 9. Critical Distinctions to Remember

**"Class vs. Contract"**
- Solidity has no classes. A contract is a persistent, always-on service deployed on-chain.
- Each `external` function is like an API endpoint — it waits for a transaction to call it.

**"Tokens vs. Wallets"**
- Tokens live in the token contract's storage.
- A wallet is just `address + private key`; it does not store token balances.

**"Multi-token vs. Multi-vault"**
- One token contract can be held by unlimited addresses (that's ERC20).
- One vault serves exactly one beneficiary (that's `immutable`).

**"sweepForeignToken vs. sweepExcess"**
- `sweepForeignToken`: recovers tokens that are **not** the main vesting token.
- `sweepExcess`: recovers the main vesting token but **only** the surplus above what's owed.

**"Otterscan visible vs. invisible"**
- Successful transactions → visible.
- Reverted transactions → never mined → invisible.

---

## 10. Big-Picture Analogy

```
Ethereum = a global shared building

  ┌───────────────────────────────────────────┐
  │  DVT Bank Branch (Token Contract)          │
  │  - All DVT balances are recorded here      │
  │  - Anyone can hold an account (any address)│
  └───────────────────────────────────────────┘

  ┌───────────────────────────────────────────┐
  │  Alice's Personal Safe-Deposit (Vault)     │
  │  - Serves only Alice                       │
  │  - Holds only DVT                          │
  │  - Has time-based release rules            │
  │  - No admin backdoor                       │
  └───────────────────────────────────────────┘

Outside the building (wallets are just ID cards):
  Funder holds a key → can: deploy vault, fund, sweep
  Alice holds a key  → can: claim (her own vault)
  Stranger's key     → can do nothing
```

**How it operates**:
1. Funder tells the DVT bank branch to move 1,000,000 DVT into the safe-deposit account (`fund`).
2. The safe-deposit box calculates how much Alice can claim based on the schedule.
3. Alice presents her key to the box (`claim`); the box instructs the DVT bank branch: "transfer X tokens from my account to Alice."
4. The DVT bank updates its ledger: safe-deposit -= X, Alice += X.
5. Alice's balance in the DVT ledger increases by X.

**No caller = nothing happens.** This is pull-based design.

---

## 11. Mental Model — The Three Layers

```
Layer 3: Users (Funder / Beneficiary)
             │
             │ Sign transactions with private keys
             ▼
Layer 2: VestingVault Contract
         (Time-locked custody logic)
             │
             │ Calls token.transfer / balanceOf
             ▼
Layer 1: ERC20 Token Contract
         (Balance ledger)
```

- **Layer 1** is a shared ledger anyone can use.
- **Layer 2** is specialized logic — one vault, one beneficiary, one schedule.
- **Layer 3** is human participation — transactions trigger contract functions.

Once you internalize these three layers, every design choice in the vault becomes derivable.
