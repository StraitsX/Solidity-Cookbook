const { expect } = require("chai");
const hre = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Forwarder Wallet Test", function () {
    let xsgdToken;
    let fWallet;
    let owner;
    let strangerTom;
    let strangerStef;
    let masterWallet;

    beforeEach(async () => {
        // xsgd
        xsgdToken = await ethers.deployContract("Spot", ["XSGD", "XSGD", 6], {});
        await xsgdToken.waitForDeployment();
        expect(await xsgdToken.decimals()).to.equal(6);

        // deploy wallet
        [owner, strangerTom, strangerStef, masterWallet] = await ethers.getSigners();
        fWallet = await ethers.deployContract("ForwarderWallet", [owner, masterWallet, xsgdToken.target], {});
        await fWallet.waitForDeployment();
    });

    
    it("Owner guard should work ", async function () {
        expect(await fWallet.owner()).to.equal(owner);
    });
    
    it("Admin sweep funds permission test ", async function () {
        await fWallet.adminSweepFunds(0, strangerStef);
        await expect(fWallet.connect(strangerTom).adminSweepFunds(100, strangerStef))
        .to.be.revertedWithCustomError(fWallet, 'OwnableUnauthorizedAccount');
    });

    it("Admin sweep funds test ", async function () {

        // Mint and sweep test
        expect(await xsgdToken.balanceOf(fWallet.target)).to.equal(0);
        await xsgdToken.mint(fWallet.target, 100)
        expect(await xsgdToken.balanceOf(fWallet.target)).to.equal(100);


        await fWallet.adminSweepFunds(10, strangerStef);
        expect(await xsgdToken.balanceOf(fWallet.target)).to.equal(90);
        expect(await xsgdToken.balanceOf(strangerStef)).to.equal(10);

        await fWallet.adminSweepFunds(10, strangerTom);
        expect(await xsgdToken.balanceOf(fWallet.target)).to.equal(80);
        expect(await xsgdToken.balanceOf(strangerStef)).to.equal(10);
    });

    
    it("Basic Sweep funds to hardcoded master wallet test ", async function () {
        // Mint and sweep test
        expect(await xsgdToken.balanceOf(fWallet.target)).to.equal(0);
        await xsgdToken.mint(fWallet.target, 100)
        expect(await xsgdToken.balanceOf(fWallet.target)).to.equal(100);

        // admin sweep funds
        await fWallet.sweepFunds(10);
        expect(await xsgdToken.balanceOf(fWallet.target)).to.equal(90);
        expect(await xsgdToken.balanceOf(masterWallet)).to.equal(10);

        // stranger sweep funds
        await fWallet.connect(strangerTom).sweepFunds(10);
        expect(await xsgdToken.balanceOf(fWallet.target)).to.equal(80);
        expect(await xsgdToken.balanceOf(masterWallet)).to.equal(20);
    });

});