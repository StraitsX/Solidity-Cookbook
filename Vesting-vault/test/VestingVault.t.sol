// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";
import {VestingVault} from "../src/VestingVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockFeeOnTransferERC20} from "./mocks/MockFeeOnTransferERC20.sol";

contract VestingVaultTest is Test {
    MockERC20 internal token;
    address internal funder = address(this);
    address internal beneficiary = address(0xB0B);
    address internal stranger = address(0x5713A);

    uint256 internal constant TOTAL_ALLOCATION = 1_000_000e18;
    uint64 internal cliffDuration = 30 days;
    uint64 internal vestingDuration = 365 days;
    uint64 internal start;

    VestingVault internal vault;

    function setUp() public {
        token = new MockERC20("Vested Token", "VTK");
        start = uint64(block.timestamp);
        vault = new VestingVault(
            address(token),
            beneficiary,
            TOTAL_ALLOCATION,
            start,
            cliffDuration,
            vestingDuration
        );
        token.mint(funder, TOTAL_ALLOCATION * 10);
    }

    function _fund() internal {
        token.approve(address(vault), TOTAL_ALLOCATION);
        vault.fund(TOTAL_ALLOCATION);
    }

    // ============ Construction / validation ============

    function test_constructor_revertsOnZeroTokenAddress() public {
        vm.expectRevert(VestingVault.ZeroTokenAddress.selector);
        new VestingVault(
            address(0),
            beneficiary,
            TOTAL_ALLOCATION,
            start,
            cliffDuration,
            vestingDuration
        );
    }

    function test_constructor_revertsOnZeroBeneficiaryAddress() public {
        vm.expectRevert(VestingVault.ZeroBeneficiaryAddress.selector);
        new VestingVault(
            address(token),
            address(0),
            TOTAL_ALLOCATION,
            start,
            cliffDuration,
            vestingDuration
        );
    }

    function test_constructor_revertsOnZeroAllocation() public {
        vm.expectRevert(VestingVault.ZeroAllocation.selector);
        new VestingVault(
            address(token),
            beneficiary,
            0,
            start,
            cliffDuration,
            vestingDuration
        );
    }

    function test_constructor_revertsOnZeroVestingDuration() public {
        vm.expectRevert(VestingVault.InvalidSchedule.selector);
        new VestingVault(
            address(token),
            beneficiary,
            TOTAL_ALLOCATION,
            start,
            0,
            0
        );
    }

    function test_constructor_revertsOnCliffGreaterThanVestingDuration()
        public
    {
        vm.expectRevert(VestingVault.InvalidSchedule.selector);
        new VestingVault(
            address(token),
            beneficiary,
            TOTAL_ALLOCATION,
            start,
            vestingDuration + 1,
            vestingDuration
        );
    }

    function test_constructor_validParamsSetImmutablesCorrectly() public {
        assertEq(address(vault.token()), address(token));
        assertEq(vault.beneficiary(), beneficiary);
        assertEq(vault.funder(), funder);
        assertEq(vault.totalAllocation(), TOTAL_ALLOCATION);
        assertEq(vault.start(), start);
        assertEq(vault.cliff(), start + cliffDuration);
        assertEq(vault.end(), start + vestingDuration);
    }

    function test_constructor_allowsCliffEqualToVestingDuration() public {
        VestingVault v = new VestingVault(
            address(token),
            beneficiary,
            TOTAL_ALLOCATION,
            start,
            vestingDuration,
            vestingDuration
        );
        assertEq(v.cliff(), v.end());
    }

    function test_constructor_allowsZeroCliffDuration() public {
        VestingVault v = new VestingVault(
            address(token),
            beneficiary,
            TOTAL_ALLOCATION,
            start,
            0,
            vestingDuration
        );
        assertEq(v.cliff(), v.start());
    }

    function test_constructor_revertsOnScheduleOverflow_notPanic() public {
        uint64 badStart = type(uint64).max - 10;
        vm.expectRevert(VestingVault.ScheduleOverflow.selector);
        new VestingVault(
            address(token),
            beneficiary,
            TOTAL_ALLOCATION,
            badStart,
            50,
            100
        );
    }

    function test_constructor_exactBoundaryNoOverflow_succeeds() public {
        uint64 boundaryStart = type(uint64).max - 100;
        VestingVault v = new VestingVault(
            address(token),
            beneficiary,
            TOTAL_ALLOCATION,
            boundaryStart,
            100,
            100
        );
        assertEq(v.end(), type(uint64).max);
    }

    function test_constructor_largerAddendCheckSufficient_noFalsePositive()
        public
    {
        // vestingDuration_'s overflow check passing must not cause a false-positive
        // revert from cliffDuration_'s (smaller) addition.
        uint64 boundaryStart = type(uint64).max - 100;
        VestingVault v = new VestingVault(
            address(token),
            beneficiary,
            TOTAL_ALLOCATION,
            boundaryStart,
            1,
            100
        );
        assertEq(v.cliff(), boundaryStart + 1);
    }

    function test_backdatedFullyVestedSchedule_immediateClaimDrainsFullAllocation()
        public
    {
        vm.warp(500 days);
        uint64 backdatedStart = uint64(block.timestamp) - 400 days;
        VestingVault v = new VestingVault(
            address(token),
            beneficiary,
            TOTAL_ALLOCATION,
            backdatedStart,
            1 days,
            30 days
        );

        token.approve(address(v), TOTAL_ALLOCATION);
        v.fund(TOTAL_ALLOCATION);

        vm.prank(beneficiary);
        v.claim();

        assertEq(v.claimed(), TOTAL_ALLOCATION);
        assertEq(token.balanceOf(beneficiary), TOTAL_ALLOCATION);
    }

    // ============ Funding ============

    function test_fund_success() public {
        token.approve(address(vault), TOTAL_ALLOCATION);

        vm.expectEmit(true, false, false, true);
        emit VestingVault.Funded(funder, TOTAL_ALLOCATION, block.timestamp);
        vault.fund(TOTAL_ALLOCATION);

        assertTrue(vault.funded());
        assertEq(token.balanceOf(address(vault)), TOTAL_ALLOCATION);
    }

    function test_fund_revertsForNonFunder() public {
        vm.prank(stranger);
        vm.expectRevert(VestingVault.NotFunder.selector);
        vault.fund(TOTAL_ALLOCATION);
    }

    function test_fund_revertsOnDoubleFund() public {
        _fund();
        token.approve(address(vault), TOTAL_ALLOCATION);
        vm.expectRevert(VestingVault.AlreadyFunded.selector);
        vault.fund(TOTAL_ALLOCATION);
    }

    function test_fund_revertsOnWrongAmount_under() public {
        token.approve(address(vault), TOTAL_ALLOCATION);
        vm.expectRevert(
            abi.encodeWithSelector(
                VestingVault.IncorrectFundingAmount.selector,
                TOTAL_ALLOCATION,
                TOTAL_ALLOCATION - 1
            )
        );
        vault.fund(TOTAL_ALLOCATION - 1);
    }

    function test_fund_revertsOnWrongAmount_over() public {
        token.approve(address(vault), TOTAL_ALLOCATION + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                VestingVault.IncorrectFundingAmount.selector,
                TOTAL_ALLOCATION,
                TOTAL_ALLOCATION + 1
            )
        );
        vault.fund(TOTAL_ALLOCATION + 1);
    }

    function test_fund_revertsWithoutApproval() public {
        vm.expectRevert();
        vault.fund(TOTAL_ALLOCATION);
    }

    function test_fund_revertsOnFeeOnTransferShortfall() public {
        MockFeeOnTransferERC20 feeToken = new MockFeeOnTransferERC20(
            "Fee Token",
            "FEE"
        );
        feeToken.mint(funder, TOTAL_ALLOCATION);
        VestingVault feeVault = new VestingVault(
            address(feeToken),
            beneficiary,
            TOTAL_ALLOCATION,
            start,
            cliffDuration,
            vestingDuration
        );

        feeToken.approve(address(feeVault), TOTAL_ALLOCATION);
        uint256 expectedReceived = TOTAL_ALLOCATION -
            ((TOTAL_ALLOCATION * 500) / 10_000);
        vm.expectRevert(
            abi.encodeWithSelector(
                VestingVault.FundingShortfall.selector,
                TOTAL_ALLOCATION,
                expectedReceived
            )
        );
        feeVault.fund(TOTAL_ALLOCATION);
    }

    // ============ Vesting math ============

    function test_vestedAmount_zeroBeforeCliff() public {
        assertEq(vault.vestedAmount(start), 0);
        assertEq(vault.vestedAmount(start + cliffDuration - 1), 0);
    }

    function test_vestedAmount_discreteJumpAtCliff() public {
        uint256 expected = (TOTAL_ALLOCATION * cliffDuration) / vestingDuration;
        assertEq(vault.vestedAmount(start + cliffDuration), expected);
        assertGt(expected, 0);
    }

    function test_vestedAmount_linearMidpoints() public {
        uint64 quarterPoint = start + vestingDuration / 4;
        uint256 expectedQuarter = (TOTAL_ALLOCATION * (vestingDuration / 4)) /
            vestingDuration;
        assertEq(vault.vestedAmount(quarterPoint), expectedQuarter);

        uint64 halfPoint = start + vestingDuration / 2;
        uint256 expectedHalf = (TOTAL_ALLOCATION * (vestingDuration / 2)) /
            vestingDuration;
        assertEq(vault.vestedAmount(halfPoint), expectedHalf);

        uint64 threeQuarterPoint = start + (vestingDuration * 3) / 4;
        uint256 expectedThreeQuarter = (TOTAL_ALLOCATION *
            ((vestingDuration * 3) / 4)) / vestingDuration;
        assertEq(vault.vestedAmount(threeQuarterPoint), expectedThreeQuarter);
    }

    function test_vestedAmount_fullAtEnd() public {
        assertEq(vault.vestedAmount(start + vestingDuration), TOTAL_ALLOCATION);
    }

    function test_vestedAmount_fullAfterEnd() public {
        assertEq(
            vault.vestedAmount(start + vestingDuration + 365 days),
            TOTAL_ALLOCATION
        );
    }

    function test_vestedAmount_zeroBeforeStart() public {
        assertEq(vault.vestedAmount(start - 1), 0);
    }

    // ============ Claiming ============

    function test_claim_revertsBeforeCliff() public {
        _fund();
        vm.prank(beneficiary);
        vm.expectRevert(VestingVault.NothingToClaim.selector);
        vault.claim();
    }

    function test_claim_atCliffTransfersJumpAmount() public {
        _fund();
        vm.warp(start + cliffDuration);
        uint256 expected = (TOTAL_ALLOCATION * cliffDuration) / vestingDuration;

        vm.prank(beneficiary);
        vault.claim();

        assertEq(token.balanceOf(beneficiary), expected);
        assertEq(vault.claimed(), expected);
    }

    function test_claim_secondCallWithNoTimeElapsed_reverts() public {
        _fund();
        vm.warp(start + cliffDuration);
        vm.prank(beneficiary);
        vault.claim();

        vm.prank(beneficiary);
        vm.expectRevert(VestingVault.NothingToClaim.selector);
        vault.claim();
    }

    function test_claim_secondCallTransfersOnlyDelta() public {
        _fund();
        vm.warp(start + cliffDuration);
        vm.prank(beneficiary);
        vault.claim();
        uint256 firstClaim = vault.claimed();

        vm.warp(start + vestingDuration / 2);
        vm.prank(beneficiary);
        vault.claim();

        uint256 secondClaimDelta = vault.claimed() - firstClaim;
        uint256 expectedTotal = (TOTAL_ALLOCATION * (vestingDuration / 2)) /
            vestingDuration;
        assertEq(vault.claimed(), expectedTotal);
        assertEq(token.balanceOf(beneficiary), firstClaim + secondClaimDelta);
    }

    function test_claim_multipleSequentialClaims_cumulativeCorrect() public {
        _fund();

        vm.warp(start + cliffDuration);
        vm.prank(beneficiary);
        vault.claim();

        vm.warp(start + vestingDuration / 3);
        vm.prank(beneficiary);
        vault.claim();

        vm.warp(start + (vestingDuration * 2) / 3);
        vm.prank(beneficiary);
        vault.claim();

        assertLe(vault.claimed(), TOTAL_ALLOCATION);
        assertEq(token.balanceOf(beneficiary), vault.claimed());
    }

    function test_claim_atEndTransfersAllRemaining() public {
        _fund();
        vm.warp(start + vestingDuration);
        vm.prank(beneficiary);
        vault.claim();

        assertEq(vault.claimed(), TOTAL_ALLOCATION);
        assertEq(token.balanceOf(beneficiary), TOTAL_ALLOCATION);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function test_claim_afterFullyClaimed_reverts() public {
        _fund();
        vm.warp(start + vestingDuration);
        vm.prank(beneficiary);
        vault.claim();

        vm.prank(beneficiary);
        vm.expectRevert(VestingVault.NothingToClaim.selector);
        vault.claim();
    }

    function test_claim_revertsForNonBeneficiary() public {
        _fund();
        vm.warp(start + cliffDuration);
        vm.prank(stranger);
        vm.expectRevert(VestingVault.NotBeneficiary.selector);
        vault.claim();
    }

    function test_claim_revertsBeforeFunded() public {
        vm.warp(start + cliffDuration);
        vm.prank(beneficiary);
        vm.expectRevert(VestingVault.NotFundedYet.selector);
        vault.claim();
    }

    function test_claim_emitsClaimedEvent() public {
        _fund();
        vm.warp(start + cliffDuration);
        uint256 expected = (TOTAL_ALLOCATION * cliffDuration) / vestingDuration;

        vm.expectEmit(true, false, false, true);
        emit VestingVault.Claimed(
            beneficiary,
            expected,
            expected,
            block.timestamp
        );
        vm.prank(beneficiary);
        vault.claim();
    }

    // ============ Sweep ============

    function test_sweepForeignToken_success() public {
        MockERC20 foreign = new MockERC20("Foreign", "FRN");
        foreign.mint(address(vault), 500e18);

        vm.expectEmit(true, true, false, true);
        emit VestingVault.Swept(
            address(foreign),
            funder,
            500e18,
            block.timestamp
        );
        vault.sweepForeignToken(address(foreign));

        assertEq(foreign.balanceOf(funder), 500e18);
        assertEq(foreign.balanceOf(address(vault)), 0);
        assertFalse(vault.funded());
        assertEq(vault.claimed(), 0);
    }

    function test_sweepForeignToken_revertsOnVestedToken() public {
        vm.expectRevert(VestingVault.CannotSweepVestedToken.selector);
        vault.sweepForeignToken(address(token));
    }

    function test_sweepForeignToken_revertsOnZeroBalance() public {
        MockERC20 foreign = new MockERC20("Foreign", "FRN");
        vm.expectRevert(VestingVault.NothingToSweep.selector);
        vault.sweepForeignToken(address(foreign));
    }

    function test_sweepForeignToken_revertsForNonFunder() public {
        MockERC20 foreign = new MockERC20("Foreign", "FRN");
        foreign.mint(address(vault), 500e18);
        vm.prank(stranger);
        vm.expectRevert(VestingVault.NotFunder.selector);
        vault.sweepForeignToken(address(foreign));
    }

    function test_sweepExcess_transfersOnlyExcess() public {
        _fund();
        token.mint(address(vault), 777e18);

        vm.expectEmit(true, true, false, true);
        emit VestingVault.Swept(
            address(token),
            funder,
            777e18,
            block.timestamp
        );
        vault.sweepExcess();

        assertEq(token.balanceOf(funder), 777e18 + (TOTAL_ALLOCATION * 9)); // leftover mint minus funded amount
        assertEq(
            token.balanceOf(address(vault)),
            TOTAL_ALLOCATION - vault.claimed()
        );
    }

    function test_sweepExcess_revertsWhenBalanceEqualsOwed() public {
        _fund();
        vm.expectRevert(VestingVault.NothingToSweep.selector);
        vault.sweepExcess();

        vm.warp(start + vestingDuration);
        vm.prank(beneficiary);
        vault.claim();

        vm.expectRevert(VestingVault.NothingToSweep.selector);
        vault.sweepExcess();
    }

    function test_sweepExcess_revertsForNonFunder() public {
        _fund();
        token.mint(address(vault), 777e18);
        vm.prank(stranger);
        vm.expectRevert(VestingVault.NotFunder.selector);
        vault.sweepExcess();
    }

    function test_sweepExcess_sweepableBeforeEnd_liveBalanceCheckNotTimeGate()
        public
    {
        _fund();
        vm.warp(start + vestingDuration / 2);
        token.mint(address(vault), 42e18);

        vault.sweepExcess();

        assertEq(
            token.balanceOf(address(vault)),
            TOTAL_ALLOCATION - vault.claimed()
        );
    }
}
