// https://github.com/OpenZeppelin/workshops/blob/master/25-defender-metatx-api/src/signer.js 

const ethSigUtil = require('eth-sig-util');

const EIP712Domain = [
  { name: 'name', type: 'string' },
  { name: 'version', type: 'string' },
  { name: 'chainId', type: 'uint256' },
  { name: 'verifyingContract', type: 'address' },
];

const OrderRedeemRequest = [
  { name: 'from', type: 'address' },
  { name: 'order_id', type: 'string' },
];

function getEscrowTypeData(chainId, verifyingContract) {
  return {
    types: {
      EIP712Domain,
      OrderRedeemRequest,
    },
    domain: {
      name: 'RetailOrderEscrow',
      version: '0.0.1',
      chainId,
      verifyingContract,
    },
    primaryType: 'OrderRedeemRequest',
  };
}

async function signTypedData(signer, from, data) {
  // If signer is a private key, use it to sign
  if (typeof signer === 'string') {
    const privateKey = Buffer.from(signer.replace(/^0x/, ''), 'hex');
    return ethSigUtil.signTypedMessage(privateKey, { data });
  }

  const [method, argData] = ['eth_signTypedData_v4', JSON.stringify(data)];
  return await signer.send(method, [from, argData]);
}

async function buildTypedData(escrow, request) {
  const chainId = await escrow.provider.getNetwork().then((n) => n.chainId);
  const typeData = getEscrowTypeData(chainId, escrow.address);
  return { ...typeData, message: request };
}

async function signOrderRedeemRequest(signer, escrow, request) {
  const toSign = await buildTypedData(escrow, request);
  const signature = await signTypedData(signer, request.from, toSign);
  return { signature, request };
}

module.exports = {
  signOrderRedeemRequest,
};
