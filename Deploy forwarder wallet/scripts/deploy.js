const hre = require("hardhat");

async function main() {
    let xsgdTokenAddress = "0xDC3326e71D45186F113a2F448984CA0e8D201995";
    let masterWalletAddress = "0xcf801268E6b45101cd974d1038b8986EDffE3D9F";
    let ownerAddress = "0xcf801268E6b45101cd974d1038b8986EDffE3D9F"
    let [deployer] = await ethers.getSigners();

    // deploy wallet
    fWallet = await hre.ethers.deployContract("ForwarderWallet", [ownerAddress, masterWalletAddress, xsgdTokenAddress], {});
    await fWallet.waitForDeployment();

    console.log(
        `Deployed to ${fWallet.target}, by: ${deployer.address}`
    );

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
