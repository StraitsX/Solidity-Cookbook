// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./DummyERC20.sol";

contract DoubleSafeTransfer {
    using SafeERC20 for DummyERC20;

    function executeDoubleSafeTransfer(
        address tokenAddress,
        address recipient1,
        address recipient2,
        uint256 amount
    ) external {
        // Instantiate the dummy ERC20 token contract
        DummyERC20 token = DummyERC20(tokenAddress);

        // Check if the sender has enough tokens to perform the double transfer
        require(
            token.balanceOf(msg.sender) >= amount * 2,
            "Insufficient token balance to perform double transfer."
        );

        // Call safeTransfer for the first recipient
        token.safeTransferFrom(msg.sender, recipient1, amount);

        // Call safeTransfer for the second recipient
        token.safeTransferFrom(msg.sender, recipient2, amount);
    }
}