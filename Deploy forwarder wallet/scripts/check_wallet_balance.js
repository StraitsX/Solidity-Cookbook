const hre = require("hardhat");

async function main() {
    let forwarderWalletAddress = "0x454dcE6ff8b9893d34b9494c237cefad35899766";
    let [deployer] = await ethers.getSigners();

    // deploy wallet
    let contract = await hre.ethers.getContractFactory("ForwarderWallet");
    let fwallet = contract.attach(forwarderWalletAddress);

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
