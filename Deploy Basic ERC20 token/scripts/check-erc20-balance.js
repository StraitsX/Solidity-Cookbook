const hre = require("hardhat");
const fs = require("fs")
const path = require("path")

const getTheAbi = () => {
  try {
    const dir = path.resolve(
      __dirname,
      "../artifacts/contracts/VictorXSGD.sol/VictorXSGD.json"
    )
    const file = fs.readFileSync(dir, "utf8")
    const json = JSON.parse(file)
    const abi = json.abi
    // console.log(`abi`, abi)

    return abi
  } catch (e) {
    console.log(`e`, e)
  }
}

async function deploy() {
  var ethers = hre.ethers;
  const ContractFactory = await ethers.getContractFactory("VictorXSGD");

  const instance = await ContractFactory.deploy();
  await instance.deployed();

  console.log(`Contract deployed to ${instance.address}`);

  return instance.address;
}

async function main() {

  const tokenContractAddress = await deploy();
  const [signer] = await hre.ethers.getSigners();
  const signerAddress = await signer.getAddress();
  console.log(`Signer Address: ${signerAddress}`);

  const abi = [
    // Add your contract's ABI here
    "function balanceOf(address owner) view returns (uint256)",
  ];

  // ensure that the address has smart contract data by checking that 
  // hre.ethers.provider.getCode(ADDRESS) returns a non 0 value
  // console.log(await hre.ethers.provider.getCode(tokenContractAddress));

  const contract = await hre.ethers.getContractAt(abi, tokenContractAddress, signer);
  const balance = await contract.balanceOf(signer.address);
  console.log(`Balance method 1: ${hre.ethers.utils.formatUnits(balance, 18)} Tokens`);

  // alternative method
  const ERC20ABI = getTheAbi();
  const token = await hre.ethers.getContractAt(ERC20ABI, tokenContractAddress, signer);
  tokenBalance = await token.balanceOf(signerAddress);
  console.log(`Balance method 2: ${ethers.utils.formatUnits(tokenBalance, 18)} Tokens`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
