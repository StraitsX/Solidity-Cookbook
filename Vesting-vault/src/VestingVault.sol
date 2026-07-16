// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title VestingVault
/// @notice Holds a single ERC20 allocation for a single beneficiary and releases it
///         according to a fixed cliff + linear vesting schedule.
/// @dev Single-token, single-beneficiary, single-funding-event design. No admin override,
///      no ownership transfer, no upgradability. The only privileged actions are: `fund`
///      (funder, once), `sweepForeignToken`/`sweepExcess` (funder, narrowly scoped recovery),
///      and `claim` (beneficiary only). Neither sweep function accepts an arbitrary
///      destination address — both always send to `funder` — so no code path in this
///      contract can redirect the vested token to anyone other than `beneficiary` (via
///      `claim`) or `funder` (via `sweepExcess`, and only for the strictly-excess portion).
contract VestingVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Errors ============

    error ZeroAddress();
    error ZeroAllocation();
    /// @dev Schedule shape is invalid: zero vesting duration, or cliff longer than vesting duration.
    error InvalidSchedule();
    /// @dev `start_ + vestingDuration_` would overflow uint64. Distinct from InvalidSchedule
    ///      because this is a numeric-range failure, not a schedule-shape failure — keeping the
    ///      selectors separate makes revert-trace triage and test assertions unambiguous.
    error ScheduleOverflow();
    error AlreadyFunded();
    error NotFunder();
    error IncorrectFundingAmount(uint256 expected, uint256 actual);
    /// @dev The amount actually received by the vault (measured via balance delta) was less
    ///      than the amount transferred, e.g. a fee-on-transfer or rebasing token. Guards
    ///      against silent under-funding, which the sweep functions cannot recover from
    ///      (they only ever recover excess, never shortfall).
    error FundingShortfall(uint256 expected, uint256 received);
    error NotBeneficiary();
    error NotFundedYet();
    error NothingToClaim();
    error NothingToSweep();
    error CannotSweepVestedToken();

    // ============ Events ============

    event Funded(address indexed funder, uint256 amount, uint256 timestamp);
    event Claimed(address indexed beneficiary, uint256 amount, uint256 totalClaimed, uint256 timestamp);
    event Swept(address indexed token, address indexed to, uint256 amount, uint256 timestamp);

    // ============ Immutable state ============

    /// @notice The ERC20 token held and released by this vault.
    IERC20 public immutable token;
    /// @notice The sole address permitted to claim vested tokens.
    address public immutable beneficiary;
    /// @notice The address that deployed this vault; sole address permitted to fund and sweep.
    address public immutable funder;
    /// @notice Total token amount to be vested over the schedule.
    uint256 public immutable totalAllocation;
    /// @notice Unix timestamp at which the vesting schedule begins.
    uint64 public immutable start;
    /// @notice Absolute unix timestamp of the cliff (start + cliffDuration). No tokens are
    ///         claimable before this timestamp.
    uint64 public immutable cliff;
    /// @notice Absolute unix timestamp at which the full allocation is vested (start + vestingDuration).
    uint64 public immutable end;

    // ============ Mutable state ============

    /// @notice True once the vault has been funded. Funding can only happen once.
    bool public funded;
    /// @notice Cumulative amount claimed by the beneficiary so far.
    uint256 public claimed;

    /// @notice Deploys a single-beneficiary linear vesting vault for one ERC20 token.
    /// @dev Backdated schedules are explicitly supported: `start_` may be in the past, including
    ///      far enough in the past that `end` is already before `block.timestamp` at deployment
    ///      time. In that case, once the vault is funded, the very first `claim()` call may
    ///      transfer the full `totalAllocation` in one transaction. This is intended behavior
    ///      for backdated grants (e.g. recording a vesting schedule for a grant that conceptually
    ///      started in the past), not a bug — no guard is added against it.
    /// @param token_ Address of the ERC20 token to be vested. Must be non-zero.
    /// @param beneficiary_ Sole address permitted to claim vested tokens. Must be non-zero.
    /// @param totalAllocation_ Total token amount to be vested over the schedule. Must be non-zero.
    /// @param start_ Unix timestamp at which the vesting schedule begins. May be in the past.
    /// @param cliffDuration_ Seconds after `start_` before which zero tokens are claimable.
    /// @param vestingDuration_ Total seconds from `start_` until 100% of the allocation is
    ///        vested. Must be non-zero and greater than or equal to `cliffDuration_`.
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
        // Overflow guard performed via subtraction so the check itself can never panic-overflow.
        // Only the larger addend (vestingDuration_) needs checking: since cliffDuration_ <=
        // vestingDuration_ is already guaranteed above, and both are added to the same base
        // (start_), if the larger sum fits in uint64 the smaller sum also fits.
        if (vestingDuration_ > type(uint64).max - start_) revert ScheduleOverflow();

        token = IERC20(token_);
        beneficiary = beneficiary_;
        funder = msg.sender;
        totalAllocation = totalAllocation_;
        start = start_;
        cliff = start_ + cliffDuration_;
        end = start_ + vestingDuration_;
    }

    /// @notice Funds the vault with the exact total allocation. Callable once only, by the funder.
    /// @dev Pull-based (uses `safeTransferFrom`): the funder must `approve` this contract for
    ///      `amount` beforehand. Exact-amount enforcement happens on the function argument, not
    ///      on contract balance, so it can't be confused by stray transfers. After the transfer,
    ///      the actual balance delta is compared against `amount` and reverts with
    ///      `FundingShortfall` on mismatch — this guards against fee-on-transfer or rebasing
    ///      tokens that would otherwise silently under-fund the vault with no recovery path
    ///      (the sweep functions can only recover excess, never a shortfall).
    /// @param amount Must exactly equal `totalAllocation`.
    function fund(uint256 amount) external nonReentrant {
        if (msg.sender != funder) revert NotFunder();
        if (funded) revert AlreadyFunded();
        if (amount != totalAllocation) revert IncorrectFundingAmount(totalAllocation, amount);

        funded = true;

        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = token.balanceOf(address(this)) - balanceBefore;
        if (received != amount) revert FundingShortfall(amount, received);

        emit Funded(msg.sender, amount, block.timestamp);
    }

    /// @notice Returns the total amount vested (unlocked, whether claimed or not) as of `timestamp`.
    /// @dev At `timestamp == cliff` exactly (when the cliff is after `start`), this is a discrete
    ///      jump to `totalAllocation * cliffDuration / vestingDuration`, NOT zero. The vesting
    ///      curve runs continuously from `(start, 0)` to `(end, totalAllocation)` throughout —
    ///      the cliff only gates whether claims are allowed before that timestamp; it does not
    ///      rebase the curve to start at 0% at the cliff.
    /// @param timestamp The timestamp to evaluate vesting at.
    /// @return The cumulative vested amount at `timestamp`, bounded by `[0, totalAllocation]`.
    function vestedAmount(uint64 timestamp) public view returns (uint256) {
        if (timestamp < cliff) return 0;
        if (timestamp >= end) return totalAllocation;
        // Multiply before divide to minimize truncation error.
        return totalAllocation * (timestamp - start) / (end - start);
    }

    /// @notice Returns the amount currently claimable (vested minus already claimed) as of now.
    /// @return The claimable amount at the current block timestamp.
    function claimableAmount() public view returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - claimed;
    }

    /// @notice Claims all currently vested and unclaimed tokens, transferring them to the beneficiary.
    /// @dev Follows checks-effects-interactions: `claimed` is updated before the token transfer.
    ///      Reverts with `NothingToClaim` if the claimable amount is zero. Has no `recipient`
    ///      parameter by design — a structural anti-redirect measure, not a runtime check. If
    ///      `start` is far enough in the past that the schedule is already fully elapsed at
    ///      funding time, the first claim may transfer the full `totalAllocation` in one call;
    ///      this is intended (see constructor NatSpec), not a bug.
    function claim() external nonReentrant {
        if (msg.sender != beneficiary) revert NotBeneficiary();
        if (!funded) revert NotFundedYet();

        uint256 amount = claimableAmount();
        if (amount == 0) revert NothingToClaim();

        claimed += amount;
        token.safeTransfer(beneficiary, amount);

        emit Claimed(beneficiary, amount, claimed, block.timestamp);
    }

    /// @notice Recovers ERC20 tokens other than the vesting token that were mistakenly sent to this contract.
    /// @dev Funder-only. Sweeps the full balance of `foreignToken` to `funder` — never an
    ///      arbitrary destination. Cannot be used on the vesting token itself; use
    ///      `sweepExcess()` for that. The `nonReentrant` guard here is required not to protect
    ///      any state of this function (it has none), but because it participates in the shared
    ///      reentrancy lock across `fund`/`claim`/`sweepForeignToken`/`sweepExcess`: without it, a
    ///      malicious `foreignToken` contract could use a transfer-hook callback to reenter
    ///      `claim()` or `fund()` mid-sweep. The lock closes that cross-function reentry path.
    /// @param foreignToken Address of the non-vesting ERC20 token to recover. Must not equal `token`.
    function sweepForeignToken(address foreignToken) external nonReentrant {
        if (msg.sender != funder) revert NotFunder();
        if (foreignToken == address(token)) revert CannotSweepVestedToken();

        uint256 amount = IERC20(foreignToken).balanceOf(address(this));
        if (amount == 0) revert NothingToSweep();

        IERC20(foreignToken).safeTransfer(funder, amount);

        emit Swept(foreignToken, funder, amount, block.timestamp);
    }

    /// @notice Recovers vesting-token balance strictly in excess of what is still owed to the beneficiary.
    /// @dev Funder-only. Sweeps only `balanceOf(this) - (totalAllocation - claimed)` — a LIVE
    ///      balance check, not a time-based gate. This matters in both directions: excess can
    ///      arrive (e.g. a stray transfer) before `end` and should be recoverable immediately
    ///      rather than waiting for the schedule to finish; and after `end`, if the beneficiary
    ///      simply hasn't claimed yet, `balance` equals `owed` exactly, so this reverts with
    ///      `NothingToSweep` rather than letting the funder claw back tokens the beneficiary is
    ///      legitimately entitled to. The comparison uses `<=` (not `<`) deliberately: exact
    ///      equality between balance and owed means zero real excess.
    function sweepExcess() external nonReentrant {
        if (msg.sender != funder) revert NotFunder();

        uint256 owed = totalAllocation - claimed;
        uint256 balance = token.balanceOf(address(this));
        if (balance <= owed) revert NothingToSweep();

        uint256 excess = balance - owed;
        token.safeTransfer(funder, excess);

        emit Swept(address(token), funder, excess, block.timestamp);
    }
}
