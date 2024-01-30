const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const { parseEther, parseUnits } = ethers.utils;

describe("XSGD Transfer", function () {
  let XSGD;
  let xsgdContract;
  const XSGDAddress = "0x70e8dE73cE538DA2bEEd35d14187F6959a8ecA96";
  const ERC20ABI = [
    "function totalSupply() view returns (uint256)",
    "function balanceOf(address account) view returns (uint256)",
    "function transfer(address recipient, uint256 amount) returns (bool)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function approve(address spender, uint256 amount) returns (bool)",
    "function transferFrom(address sender, address recipient, uint256 amount) returns (bool)",
  ];

  const vitalik_address = "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B";
  const toAddress = "0x8CC4D23D8556Fdb5875F17b6d6D7149380F24D93";
  const XSGDTreasuryAddress = "0x90f25dc48580503c6cE7735869965C4bc491797b";
  const gasLimit = 30000000;

  beforeEach(async function () {
    // Connect to XSGD contract
    XSGD = await ethers.getContractAt(ERC20ABI, XSGDAddress);
  });

  it("Should transfer ETH to XSGD Treasury", async function () {
    const signer = await ethers.getImpersonatedSigner(vitalik_address);
    const initialBalance = await signer.getBalance();

    // Send ETH to XSGD treasury
    const txn = {
      to: XSGDTreasuryAddress,
      value: parseEther("10"),
      gasLimit: gasLimit,
    };

    const receipt = await signer.sendTransaction(txn);
    await receipt.wait();

    const finalBalance = await signer.getBalance();
    expect(finalBalance).to.be.lt(initialBalance);
  });

  it("Should transfer XSGD tokens", async function () {
    const signer = await ethers.getImpersonatedSigner(XSGDTreasuryAddress);
    xsgdContract = XSGD.connect(signer);

    const initialBalance = await xsgdContract.balanceOf(toAddress);

    // Transfer XSGD tokens
    const amount = parseUnits("10", 6);
    const tx = await xsgdContract.transfer(toAddress, amount, { gasLimit });
    await tx.wait();

    const finalBalance = await xsgdContract.balanceOf(toAddress);
    expect(finalBalance).to.equal(initialBalance.add(amount));
  });
});
