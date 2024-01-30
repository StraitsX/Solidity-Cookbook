# README: Mainnet Fork and XSGD Transfer Demo

This project demonstrates how to use a mainnet fork and impersonate accounts to transfer XSGD tokens between Ethereum addresses.

## Env

TODO:
- [] Set up a nix-shell for the dev env.

## Mainnet Fork Process

The project uses Hardhat to create a local Ethereum mainnet fork for testing purposes. The fork is configured in the hardhat.config.js file, where the url property is set to the Ethereum RPC URL.

During the forking process, Hardhat creates a local instance of the Ethereum mainnet, allowing you to interact with it as if you were using the real mainnet. This allows you to test your code without risking real assets or waiting for the mainnet transaction confirmation times.

When working with a forked environment, you can also impersonate accounts, which allows you to perform transactions on behalf of other users without having access to their private keys. In this project, we impersonate Vitalik's address to send ETH to the XSGD Treasury address for gas, and then impersonate the XSGD Treasury address to transfer XSGD tokens to the target address.

Please note that these scripts and tests are for demonstration purposes only and should not be used in a production environment.


## Configuration

1. Create a `.env` file in the root of your project with the following content:
```
    ETHEREUM_RPC_URL=<replace with your RPC URL>
```

## Usage

### Transfer XSGD Tokens
1. Run the impersonate-transfer.js script to transfer 10 XSGD tokens from the XSGD Treasury address to the target address:
```bash
npx hardhat run scripts/impersonate-transfer.js
```

### Run tests
```bash
npx hardhat test
```
The test suite will ensure the ETH transfer to the XSGD Treasury(for gas) and XSGD token transfer are successful.






