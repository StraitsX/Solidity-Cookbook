// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IForwarderWallet {
    
    /// Sweep ERC20 tokens from this smart contract wallet to a hardcoded destination wallet
    /// @param erc20Amount the amount of erc20 tokens to sweep funds out of the smart contract
    function sweepFunds(uint256 erc20Amount) external;

    /// Sweep ERC20 tokens from this smart contract wallet to a specified destination wallet
    /// @param erc20Amount the amount of erc20 tokens to sweep funds out of the smart contract
    /// @param targetWallet destination wallet address
    function adminSweepFunds(uint256 erc20Amount, address targetWallet) external;
    
    /// Returns the hardcoded address that this wallet can sweep to
    function getMasterWallet() external view  returns (address);
}