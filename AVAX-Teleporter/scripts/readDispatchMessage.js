const { ethers } = require("hardhat");

async function main() {
  const dispatchReceiver = (
    await ethers.getContractFactory("DispatchReceiver")
  ).attach("0x63681558c1b680E43bbCAdC0CeD21075854bBA87");
  const lastMessage = await dispatchReceiver.lastMessage();
  console.log("Last message:", lastMessage);
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
