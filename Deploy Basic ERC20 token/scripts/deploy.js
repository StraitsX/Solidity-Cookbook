const hre = require("hardhat");

// run the script like so npx hardhat run --network <network-name> scripts/deploy.ts
async function main() {
  var ethers = hre.ethers;
  const ContractFactory = await ethers.getContractFactory("VictorXSGD");

  const instance = await ContractFactory.deploy();
  await instance.deployed();

  console.log(`Contract deployed to ${instance.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
