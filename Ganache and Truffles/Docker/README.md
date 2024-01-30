# Introduction
This cookbook will teach you how to deploy to a local chain (ganache) by using Docker files.

# Pre-Installation
- Install [Docker & docker-compose](https://docs.docker.com/compose/install/)
- (Optional) [Orbstack](https://orbstack.dev/): to have better performance for running Docker

# Directly use this project to play around
## Bootstrapping
- Run the shell directly, Docker will help you build the essential images and run necessary containers
  ```shell
  docker-compose run --rm deployment-playground
  ```

> All the following commands are on the shell of the `deployment-playground` docker container
- Install neccessary packages
  ```shell
  npm install
  ```
## Commands
- Run tests
  ```shell
  npm exec truffle test
  ```
- Deploy the contracts
  ```shell
  npm exec truffle migrate
  ```
- Truffle Console
  ```shell
  npm exec truffle console
  ```
- Compile smart contracts
  ```shell
  npm exec truffle compile
  ```

# The steps to setup the project from scratch
## Build Images
- Make sure the `Dockerfile` and `docker-compose.yml` is in place
- Run the shell directly, Docker will help you build the essential images and run necessary containers
  ```shell
  docker-compose run --rm deployment-playground
  ```


## Initialize the project
> All the following commands are on the shell of the `deployment-playground` docker container

- Initialize a node project
  ```shell
  npm init
  ```
- Create `.gitignore` file
  ```shell
  cat <<EOT >> .gitignore
  node_modules/
  tmp/
  EOT
  ```
- Install Truffle
  ```shell
  npm install --save truffle
  ```
- Initialize truffle project
  ```shell
  npm exec truffle init
  ```

## Truffle configurations
- Setup the connection config for the ganache network
  ```js
  development: {
    host: "ganache", // refers to the ganache service name of docker-compose.yml
    port: 7545, // refers to the ganache port in docker-compose.yml
    network_id: "5777", // refers to the chain network id in docker-compose.yml
  },
  ```

- (Alternatives) Ganache GUI
  ```js
  development: {
    host: "host.docker.internal", // Docker to connect to the original local network
    port: 7546, // refers to what you have setup on GUI
    network_id: "5777", // refers to what you have setup on GUI
  }
  ```

## Contract development
> All the following commands are on the shell of the `deployment-playground` docker container
- Create a contract file
  ```shell
  npm exec truffle create contract HelloWorld
  ```
- Example of the content of `HelloWorld.sol`
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity >=0.4.22 <0.9.0;

  contract HelloWorld {
      function sayHelloWorld() public pure returns (string memory) {
          return "Hello World";
      }
  }
  ```

## Migration files setup
> Reference: https://trufflesuite.com/docs/truffle/how-to/contracts/run-migrations/
- Create your first migration file to deploy `HelloWorld`: `migrations/1_deploy_hello_world.js`
  ```js
  var HelloWorld = artifacts.require("HelloWorld");

  module.exports = function(deployer) {
    // deployment steps
    deployer.deploy(HelloWorld);
  };
  ```

## Testing
> All the following commands are on the shell of the `deployment-playground` docker container

- Create test file
  ```shell
  npm exec truffle create test HelloWorld
  ```

- Modify the test, refer to the [guideline](https://trufflesuite.com/docs/truffle/how-to/debug-test/write-tests-in-javascript/). Example:
  ```js
  contract("HelloWorld", function (/* accounts */) {
    it("should assert true", async function () {
      const instance = await HelloWorld.deployed();
      const result = await instance.sayHelloWorld.call();
      return assert.equal(result, "Hello World", "The result is not Hello World");
    });
  });
  ```
- Run your test
  ```shell
  npm exec truffle test

  # If you want to run specific file
  npm exec truffle test ./test/hello_world.js
  ```


---
