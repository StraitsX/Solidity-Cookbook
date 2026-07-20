// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";
import {VestingVault} from "../src/VestingVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract VestingVaultFuzzTest is Test {
    MockERC20 internal token;
    address internal funder = address(this);
    address internal beneficiary = address(0xB0B);

    uint256 internal constant TOTAL_ALLOCATION = 1_000_000e18;
    uint64 internal cliffDuration = 30 days;
    uint64 internal vestingDuration = 365 days;
    uint64 internal start;

    VestingVault internal vault;

    function setUp() public {
        token = new MockERC20("Vested Token", "VTK");
        start = uint64(block.timestamp);
        vault = new VestingVault(address(token), beneficiary, TOTAL_ALLOCATION, start, cliffDuration, vestingDuration);
        token.mint(funder, TOTAL_ALLOCATION * 10);
        token.approve(address(vault), TOTAL_ALLOCATION);
        vault.fund(TOTAL_ALLOCATION);
    }

    /// @dev Monotonicity: vestedAmount is non-decreasing in timestamp.
    function testFuzz_vestedAmount_monotonic(uint64 t1, uint64 t2) public view {
        t1 = uint64(bound(t1, 0, type(uint64).max - 1));
        t2 = uint64(bound(t2, t1, type(uint64).max));
        assertLe(vault.vestedAmount(t1), vault.vestedAmount(t2));
    }

    /// @dev Boundedness: 0 <= vestedAmount(t) <= totalAllocation for any t.
    function testFuzz_vestedAmount_bounded(uint64 t) public view {
        uint256 v = vault.vestedAmount(t);
        assertGe(v, 0);
        assertLe(v, TOTAL_ALLOCATION);
    }

    /// @dev claimableAmount() == vestedAmount(now) - claimed at any fuzzed timestamp.
    function testFuzz_claimableAmount_invariant(uint64 warpTo) public {
        warpTo = uint64(bound(warpTo, start, start + vestingDuration + 365 days));
        vm.warp(warpTo);
        assertEq(vault.claimableAmount(), vault.vestedAmount(uint64(block.timestamp)) - vault.claimed());
    }

    /// @dev Sequential claims at fuzzed intervals never exceed totalAllocation cumulatively,
    ///      and equal vestedAmount(final) once claimed at/after end.
    function testFuzz_sequentialClaims_cumulativeNeverExceedsTotal(uint64 t1, uint64 t2, uint64 t3) public {
        t1 = uint64(bound(t1, start, start + vestingDuration));
        t2 = uint64(bound(t2, t1, start + vestingDuration));
        t3 = uint64(bound(t3, t2, start + vestingDuration + 1));

        vm.warp(t1);
        if (vault.claimableAmount() > 0) {
            vm.prank(beneficiary);
            vault.claim();
        }
        assertLe(vault.claimed(), TOTAL_ALLOCATION);

        vm.warp(t2);
        if (vault.claimableAmount() > 0) {
            vm.prank(beneficiary);
            vault.claim();
        }
        assertLe(vault.claimed(), TOTAL_ALLOCATION);

        vm.warp(t3);
        if (vault.claimableAmount() > 0) {
            vm.prank(beneficiary);
            vault.claim();
        }
        assertLe(vault.claimed(), TOTAL_ALLOCATION);

        if (t3 >= start + vestingDuration) {
            assertEq(vault.claimed(), TOTAL_ALLOCATION);
        }
    }

    /// @dev Extreme totalAllocation values combined with realistic timestamps should not
    ///      unexpectedly overflow in the linear branch.
    function testFuzz_extremeAllocation_noUnexpectedOverflow(uint128 allocationSeed, uint64 midpoint) public {
        uint256 allocation = uint256(allocationSeed) + 1; // avoid zero allocation
        MockERC20 t2 = new MockERC20("Big", "BIG");
        uint64 s = uint64(block.timestamp);
        uint64 cliffDur = 10 days;
        uint64 vestDur = 100 days;
        VestingVault v2 = new VestingVault(address(t2), beneficiary, allocation, s, cliffDur, vestDur);

        t2.mint(funder, allocation);
        t2.approve(address(v2), allocation);
        v2.fund(allocation);

        midpoint = uint64(bound(midpoint, s + cliffDur, s + vestDur));
        uint256 vested = v2.vestedAmount(midpoint);
        assertLe(vested, allocation);
    }

    /// @dev sweepExcess always sweeps exactly the injected excess, regardless of schedule
    ///      position (before/at/after cliff, before/at/after end), and never touches owed.
    function testFuzz_sweepExcess_exactAmountAtAnySchedulePosition(uint64 warpTo, uint96 excessSeed) public {
        warpTo = uint64(bound(warpTo, start, start + vestingDuration + 365 days));
        uint256 excess = uint256(excessSeed) + 1;

        vm.warp(warpTo);
        if (vault.claimableAmount() > 0) {
            vm.prank(beneficiary);
            vault.claim();
        }

        token.mint(address(vault), excess);
        uint256 owed = TOTAL_ALLOCATION - vault.claimed();

        vault.sweepExcess();

        assertEq(token.balanceOf(address(vault)), owed);
    }
}
