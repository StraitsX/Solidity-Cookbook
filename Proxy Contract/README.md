# Proxy Smart Contract
A proxy smart contract is a type of smart contract that allows for the upgradeability of other contracts in the Ethereum ecosystem. With a proxy smart contract, developers can change the behavior of a contract without having to redeploy it or migrate its data to a new contract.

## How to use this example
```
nvm use v18.16.0
npm install 
npx hardhat test
```

## How it Works
A proxy smart contract works by delegating calls to another contract known as the implementation contract. The proxy contract does not contain the logic of the contract it is proxying for, but rather, it contains the address of the implementation contract and forwards any calls made to it.

When a user interacts with the proxy contract, the proxy contract simply forwards the call to the implementation contract. The implementation contract executes the logic and returns the result to the proxy contract, which then returns the result to the user.

Read more here: 
- https://medium.com/coinmonks/proxy-pattern-and-upgradeable-smart-contracts-45d68d6f15da 
- https://eips.ethereum.org/EIPS/eip-1967
- https://ethereum.stackexchange.com/questions/140208/what-do-we-mean-by-collision-prevention-when-we-are-writing-proxy-contract-for-a 
- https://medium.com/1milliondevs/solidity-storage-layout-for-proxy-contracts-and-diamonds-c4f009b6903 