# Overview
- create an .env file and fill up API_URL and MNEMONIC values

## Deploying the contract

You can target any network from your Hardhat config using:

```
npx hardhat run --network <network-name> scripts/deploy.js
npx hardhat run --network polygon scripts/deploy.js
```

## Testing
```
$ npx hardhat test
```

## Check your balance first 
For sanity check - ensure that have enough gas to do any deployment first.

```
npx hardhat run scripts/check-balance.js --network mumbai 
```

## To add source code and verify:

```
npx hardhat verify --network polygon CONTRACT_ADDRESS constructor_arg1 arg2 arg3
```

List of supported Etherscan networks that hardhat is able to verify for you:
```
npx hardhat verify --list-networks
```