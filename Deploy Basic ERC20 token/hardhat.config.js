require("@nomicfoundation/hardhat-toolbox");
const dotenv = require("dotenv");
dotenv.config({path: __dirname + '/.env'});
const { API_URL, MNEMONIC } = process.env;


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  defaultNetwork: "hardhat",  // change this to mumbai network when ready to deploy to polygon mumbai
  networks: {
    hardhat: {
    },
    mumbai: {
      url: API_URL,

      accounts: {
        mnemonic: MNEMONIC,
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
        passphrase: "",
      },

    }
  },

  // for verifying source code contract
  etherscan: {
    apiKey: {
      polygonMumbai: "7E5R461T3GA968ANK43AJA4RW47PDBG79G" // victor's polygonscan api key
    }
  }

};
