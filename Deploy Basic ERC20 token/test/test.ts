import { expect } from "chai";
import { ethers } from "hardhat";

describe("VictorXSGD", function () {
  it("Test contract", async function () {
    const ContractFactory = await ethers.getContractFactory("VictorXSGD");

    const instance = await ContractFactory.deploy();
    await instance.deployed();

    expect(await instance.name()).to.equal("victorXSGD");
  });
});
