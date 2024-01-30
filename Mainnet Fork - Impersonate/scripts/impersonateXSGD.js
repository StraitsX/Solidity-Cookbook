const { ethers } = require("hardhat");

async function main() {
  const XSGDTreasuryAddress = "0x90f25dc48580503c6cE7735869965C4bc491797b";
  const vitalik_address = "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B";
  const toAddress = "0x8CC4D23D8556Fdb5875F17b6d6D7149380F24D93";
  const gasLimit = 30000000

  const vitalkSigner = await ethers.getImpersonatedSigner(vitalik_address);

  console.log(
    "Vitalik account before transaction",
    ethers.utils.formatEther(await vitalkSigner.getBalance())
  );

  // send ETH to XSGD treasury for gas
  const txn = {
    to: XSGDTreasuryAddress,
    value: ethers.utils.parseEther("10"),
    gasLimit: gasLimit,
  };

  const recieptTx = await vitalkSigner.sendTransaction(txn);

  await recieptTx.wait();

  console.log(`Transaction successful with hash: ${recieptTx.hash}`);
  console.log(
    "Vitalik account after transaction",
    ethers.utils.formatEther(await vitalkSigner.getBalance())
  );

  const signer = await ethers.getImpersonatedSigner(XSGDTreasuryAddress);

  console.log(
    "XSGD treasury ETH balance before transaction",
    ethers.utils.formatEther(await signer.getBalance())
  );

  // Set up XSGD contract
  const XSGDAddress = "0x70e8dE73cE538DA2bEEd35d14187F6959a8ecA96"; // proxy address
  const ERC20ABI = [
    "function totalSupply() view returns (uint256)",
    "function balanceOf(address account) view returns (uint256)",
    "function transfer(address recipient, uint256 amount) returns (bool)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function approve(address spender, uint256 amount) returns (bool)",
    "function transferFrom(address sender, address recipient, uint256 amount) returns (bool)",
  ]; // IERC20 ABI

  const XSGDContract = new ethers.Contract(XSGDAddress, ERC20ABI, signer);

  // Transfer 10 XSGD to the target account
  const targetAddress = toAddress;
  const amount = ethers.utils.parseUnits("10", 6);

  const tx = await XSGDContract.transfer(targetAddress, amount, { gasLimit });
  const receipt = await tx.wait();

  console.log(`Transfer of 10 XSGD completed. Transaction hash: ${receipt.transactionHash}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });