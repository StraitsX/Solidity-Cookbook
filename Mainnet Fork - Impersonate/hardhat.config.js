require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */

/** set a forking param to the default network to fork the main net */
module.exports = {
  solidity: "0.8.18",
  networks: {
    hardhat: {
      forking: {
        url: process.env.ETHEREUM_RPC_URL,
        blockNumber: 17051500,
        eip1559: true,
      },
      chianId: 1,
    }
  }
};
