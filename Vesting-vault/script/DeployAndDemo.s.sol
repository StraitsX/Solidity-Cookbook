// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Script, console} from "forge-std/Script.sol";
import {VestingVault} from "../src/VestingVault.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

/// @notice Local demonstration script: deploys a vesting vault, funds it, advances time via
///         `vm.warp`, claims in two stages, and demonstrates the sweep recovery path.
/// @dev `vm.warp` only works in a local Foundry execution context (anvil / `forge script`
///      simulation). This script is a local demonstration of the full lifecycle, not a
///      production deployment procedure — on a live chain, vesting/claims happen naturally
///      as real time passes, not via `vm.warp`.
contract DeployAndDemo is Script {
    uint256 internal constant TOTAL_ALLOCATION = 1_000_000e18;
    uint64 internal constant CLIFF_DURATION = 30 days;
    uint64 internal constant VESTING_DURATION = 365 days;

    function run() external {
        uint256 deployerKey = vm.envOr("PRIVATE_KEY", uint256(1));
        address deployer = vm.addr(deployerKey);

        uint256 beneficiaryKey = vm.envOr("BENEFICIARY_PRIVATE_KEY", uint256(2));
        address beneficiary = vm.addr(beneficiaryKey);

        address tokenAddress = vm.envOr("TOKEN_ADDRESS", address(0));

        vm.startBroadcast(deployerKey);

        MockERC20 token;
        if (tokenAddress == address(0)) {
            token = new MockERC20("Demo Vested Token", "DVT");
            token.mint(deployer, TOTAL_ALLOCATION);
            console.log("Deployed MockERC20 vesting token at:", address(token));
        } else {
            token = MockERC20(tokenAddress);
            console.log("Using existing token at:", tokenAddress);
        }

        uint64 start = uint64(block.timestamp);
        VestingVault vault =
            new VestingVault(address(token), beneficiary, TOTAL_ALLOCATION, start, CLIFF_DURATION, VESTING_DURATION);
        console.log("Deployed VestingVault at:", address(vault));
        console.log("  beneficiary:", beneficiary);
        console.log("  totalAllocation:", TOTAL_ALLOCATION);
        console.log("  cliff:", vault.cliff());
        console.log("  end:", vault.end());

        token.approve(address(vault), TOTAL_ALLOCATION);
        vault.fund(TOTAL_ALLOCATION);
        console.log("Funded vault. Vault balance:", token.balanceOf(address(vault)));

        vm.stopBroadcast();

        // --- Time advancement + first claim (past cliff, mid-schedule) ---
        vm.warp(vault.cliff() + 30 days);
        vm.startBroadcast(beneficiaryKey);
        uint256 beforeFirstClaim = token.balanceOf(beneficiary);
        vault.claim();
        console.log(
            "First claim at cliff+30d. Beneficiary balance change:", token.balanceOf(beneficiary) - beforeFirstClaim
        );
        vm.stopBroadcast();

        // --- Time advancement + second claim (full unlock at end) ---
        vm.warp(vault.end());
        vm.startBroadcast(beneficiaryKey);
        uint256 beforeSecondClaim = token.balanceOf(beneficiary);
        vault.claim();
        console.log(
            "Second claim at end. Beneficiary balance change:", token.balanceOf(beneficiary) - beforeSecondClaim
        );
        console.log("Total claimed:", vault.claimed());
        vm.stopBroadcast();

        // --- Sweep demonstration: a stray foreign-token transfer, recovered by the funder ---
        vm.startBroadcast(deployerKey);
        MockERC20 strayToken = new MockERC20("Stray", "STRY");
        uint256 strayAmount = 123e18;
        strayToken.mint(address(vault), strayAmount);
        console.log("Simulated stray foreign-token transfer to vault:", strayAmount);

        uint256 funderBalanceBefore = strayToken.balanceOf(deployer);
        vault.sweepForeignToken(address(strayToken));
        uint256 funderBalanceAfter = strayToken.balanceOf(deployer);
        console.log("Swept foreign token. Funder balance change:", funderBalanceAfter - funderBalanceBefore);
        vm.stopBroadcast();

        console.log("Demo complete. Vault fully drained:", token.balanceOf(address(vault)) == 0);
    }
}
