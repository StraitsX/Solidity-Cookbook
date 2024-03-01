// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IForwarderWallet.sol";

contract ForwarderWallet is IForwarderWallet, Pausable, Ownable {

    // Funds can only be swept to this master wallet address
    address public masterWallet = address(0);

    // Underlying ERC20 tokens
    address public walletToken  = address(0);

    constructor(address initialOwner, address _masterWallet, address erc20TokenAddress) Ownable(initialOwner) {
        require(_masterWallet != address(0), "Address cannot be null");
        require(erc20TokenAddress != address(0), "Address cannot be null");

        masterWallet = _masterWallet;
        walletToken = erc20TokenAddress;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function getMasterWallet() public view virtual returns (address) {
        return masterWallet;
    }

    function getWalletBalance() public view virtual returns (uint256) {
        ERC20 erc20 = ERC20(walletToken);
        return erc20.balanceOf(address(this));
    }

    function sweepFunds(uint256 erc20Amount) external {
        ERC20 erc20 = ERC20(walletToken);
        SafeERC20.safeTransfer(erc20, masterWallet, erc20Amount);
    }

    // @dev Sweeps ERC20 funds from the contract to a specified wallet
    // @param erc20Amount The amount of ERC20 tokens to sweep
    // @param targetWallet The wallet to sweep the ERC20 tokens to
    function adminSweepFunds(uint256 erc20Amount, address targetWallet) external onlyOwner {
        ERC20 erc20 = ERC20(walletToken);
        SafeERC20.safeTransfer(erc20, targetWallet, erc20Amount);
    }

    /**
     * @dev Allows the admin to rescue funds by transferring ERC20 tokens from the contract to a specified wallet.
     * @param erc20TokenContract The address of the ERC20 token contract.
     * @param erc20Amount The amount of ERC20 tokens to transfer.
     * @param targetWallet The address of the wallet to receive the ERC20 tokens.
     */
    function adminRescueFunds(
        address erc20TokenContract, 
        uint256 erc20Amount, 
        address targetWallet
    ) external onlyOwner {
        ERC20 erc20 = ERC20(erc20TokenContract);
        SafeERC20.safeTransfer(erc20, targetWallet, erc20Amount);
    }

}
