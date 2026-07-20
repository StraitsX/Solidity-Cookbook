## Concept 

support one ERC 20 token and one beneficiary

accept a total allocation, start time, cliff duration, and vesting duration during deployment

be funded once by the deployer before vesting begins

unlock nothing before the cliff

unlock tokens linearly after the cliff

unlock the full allocation when the vesting duration ends

allow the beneficiary to make multiple partial claims

prevent anyone from claiming more than the total allocation

prevent unauthorized users from receiving the tokens

emit events when the contract is funded and tokens are claimed


## Setup

After cloning this repo, install the Foundry dependencies 

```shell
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge build
```

See [`STEP_BY_STEP_WALKTHROUGH.md`](./STEP_BY_STEP_WALKTHROUGH.md) for a full local demo against Anvil + Otterscan.


## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/DeployAndDemo.s.sol:DeployAndDemo --rpc-url <your_rpc_url> --broadcast
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
