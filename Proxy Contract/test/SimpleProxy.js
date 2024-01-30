const { expect } = require("chai");
const { ethers } = require("hardhat");

let proxy, logic;
async function deployContracts() {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    let Proxy = await ethers.getContractFactory("SimpleProxy");
    proxy = await Proxy.deploy();
    let Logic = await ethers.getContractFactory("ProxyImplementation");
    logic = await Logic.deploy();

    console.log("Proxy deployed at: ", proxy.address);
    console.log("Logic deployed at: ", logic.address);

}

describe("SimpleProxy", async function () {
    before(async () => {
        await deployContracts();
    });

    it("Set logic", async () => {
        await proxy.setImplementation(logic.address);
    });

    it("Testing Simple Proxy call", async () => {
        const Implementation = await ethers.getContractFactory("ProxyImplementation");
        const proxyContract = await Implementation.attach(
            proxy.address // The deployed contract address
        );

        // Set Proxy Storage Location
        await proxyContract.setNumber(20);
        expect (await proxyContract.getNumber()).to.eq(20);
        await proxyContract.setNumber(30);
        expect (await proxyContract.getNumber()).to.eq(30);
        
        // Logic contract storage location
        await logic.setNumber(111);
        expect(await logic.getNumber()).to.eq(111);

        // Proxy storage doesnt change
        expect (await proxyContract.getNumber()).to.eq(30);
    });

    it("Testing Simple Proxy Call in another way", async () => {

        const myProxy = new ethers.Contract(
            proxy.address,       
            ["function setNumber(uint _number) external", 
            "function getNumber() external view returns(uint)"],
            owner
        );

        // Set Proxy Storage Location
        await myProxy.setNumber(20);
        expect (await myProxy.getNumber()).to.eq(20);
        await myProxy.setNumber(30);
        expect (await myProxy.getNumber()).to.eq(30);
        
        // Logic contract storage location
        await logic.setNumber(111);
        expect(await logic.getNumber()).to.eq(111);

        // Proxy storage doesnt change
        expect (await myProxy.getNumber()).to.eq(30);
    });

});