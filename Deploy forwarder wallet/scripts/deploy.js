const hre = require("hardhat");

async function main() {
    let xsgdTokenAddress = "0xDC3326e71D45186F113a2F448984CA0e8D201995";
    let masterWalletAddress = "0x141ecc080d64e5663c726c631b2fcf41be8ec189";
    let ownerAddress = "0x768d95166eD5E1780d3631756446C44C77e1aF39"
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
