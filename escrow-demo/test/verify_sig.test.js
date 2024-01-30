const { expect } = require('chai');
const { ethers } = require('hardhat');
const { signOrderRedeemRequest } = require('../scripts/signer.js');
async function deploy(name, ...params) {
  const Contract = await ethers.getContractFactory(name);
  return await Contract.deploy(...params).then((f) => f.deployed());
}
describe('RetailOrderEscrow', function () {
  beforeEach(async function () {
    this.escrow = await deploy('RetailOrderEscrow');
    this.accounts = await ethers.getSigners();
    this.signer = this.accounts[2];
  });

  it('Should return true for valid signatures', async function () {
    const { escrow, signer } = this;

    const { request, signature } = await signOrderRedeemRequest(
      signer.provider,
      escrow,
      {
        from: signer.address,
        order_id: 'order_1',
      },
    );

    // Verify the order redeem request
    const isVerified = await escrow.verify(request, signature);

    expect(isVerified).to.be.true;
  });

  it('Should return false for invalid request', async function () {
    const { escrow, signer } = this;

    const { request, signature } = await signOrderRedeemRequest(
      signer.provider,
      escrow,
      {
        from: signer.address,
        order_id: 'order_1',
      },
    );

    const invalidRequest = {
      from: signer.address,
      order_id: 'invalid_order_id',
    };
    // Verify the order redeem request
    const isVerified = await escrow.verify(invalidRequest, signature);

    expect(isVerified).to.be.false;
  });
});
