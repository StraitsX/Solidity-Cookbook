const { ethers, getNamedAccounts } = require("hardhat");

async function main() {
  const { deployer } = await getNamedAccounts();
  const CChainSender = await ethers.getContractFactory("CChainSender");
  const cChainSender = CChainSender.attach("0x5201D8EF22bA3090eA3329d57F082801783A8558").connect(
    ethers.provider.getSigner(deployer)
  );

  console.log("Sending message to DispatchReceiver from Fuji to dispatch");
  const sendToDispatchTxn = await cChainSender.sendMessage(
    "0x63681558c1b680E43bbCAdC0CeD21075854bBA87", // destination contract address
    "hello teleporter!" // message
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
