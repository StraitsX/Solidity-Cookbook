# Overview
- create an .env file and fill up API_URL and MNEMONIC values

## Deploying the contract

You can target any network from your Hardhat config using:

```
npx hardhat run --network <network-name> scripts/deploy.ts
npx hardhat run --network mumbai scripts/deploy.ts
npx hardhat run scripts/deploy.ts
```



## Check your balance first 
For sanity check - ensure that have enough gas to do any deployment first.

```
npx hardhat run scripts/check-balance.js --network mumbai 
```

## To add source code and verify:

```
npx hardhat verify --network mumbai CONTRACT_ADDRESS
```

List of supported Etherscan networks that hardhat is able to verify for you:
```
npx hardhat verify --list-networks
```