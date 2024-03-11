const hre = require("hardhat");

async function main() {
    let [deployer] = await ethers.getSigners();

    // deploy wallet
    let contract = await hre.ethers.getContractFactory("VictorXSGD");

    console.log(
        `Wallet balance: ${await fwallet.getWalletBalance()}, signer: ${deployer.address}`
    );
   
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
