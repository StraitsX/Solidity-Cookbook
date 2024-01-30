const hre = require("hardhat");

async function main() {
    let xsgdTokenAddress = "0xDC3326e71D45186F113a2F448984CA0e8D201995";
    let forwarderWalletAddress = "0x454dcE6ff8b9893d34b9494c237cefad35899766";
    let sweepAmt = 1;
    let [deployer] = await ethers.getSigners();

    // deploy wallet
    let contract = await hre.ethers.getContractFactory("ForwarderWallet");
    let fwallet = contract.attach(forwarderWalletAddress);


    console.log(
        `Wallet balance: ${await fwallet.getWalletBalance()}`
    );

    let results = await fwallet.sweepFunds(sweepAmt);
    let txnRespReceipt = await results.wait();
    let txnData = await txnRespReceipt.getTransaction();

    console.log(
        `Sweeped funds of amount ${sweepAmt}, txn: ${txnData.hash}`
    );

    console.log(
        `After Sweep Wallet balance: ${await fwallet.getWalletBalance()}`
    );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
