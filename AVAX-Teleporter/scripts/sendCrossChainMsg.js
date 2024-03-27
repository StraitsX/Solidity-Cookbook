const { ethers, getNamedAccounts, deployments } = require("hardhat");

async function main() {
  const { deployer } = await getNamedAccounts();
  const CChainSender = await ethers.getContractFactory("CChainSender");
  const cChainSender = CChainSender.attach(
    "0x124eDB77c52c7fb707AeeF7695342D5B3f999d55"
  ).connect(await ethers.provider.getSigner(deployer));

  console.log("Sending message to DispatchReceiver from Fuji to dispatch");
  const sendToDispatchTxn = await cChainSender.sendMessage(
    "0x124eDB77c52c7fb707AeeF7695342D5B3f999d55",
    "this is from fuji c chain"
  );
  await sendToDispatchTxn.wait();
  console.log("done");
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
