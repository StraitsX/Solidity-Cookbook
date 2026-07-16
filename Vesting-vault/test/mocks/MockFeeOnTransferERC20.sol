// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Mintable ERC20 that deducts a fee on every transfer/transferFrom, so the
///         recipient receives less than the nominal amount. Used specifically to test
///         that `VestingVault.fund()` reverts with `FundingShortfall` when the actual
///         received amount is less than expected.
contract MockFeeOnTransferERC20 is ERC20 {
    uint256 public constant FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        _transfer(_msgSender(), to, amount - fee);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        _spendAllowance(from, _msgSender(), amount);
        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        _transfer(from, to, amount - fee);
        return true;
    }
}
