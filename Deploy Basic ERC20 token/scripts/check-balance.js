const hre = require("hardhat");

async function main() {
  const [signer] = await hre.ethers.getSigners();

  const balance = await signer.getBalance();
  console.log(`Balance: ${hre.ethers.utils.formatEther(balance)} MATIC`);

  const signerAddress = await signer.getAddress();
  console.log(`Signer Address: ${signerAddress}`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
