require("@nomicfoundation/hardhat-toolbox");
const dotenv = require("dotenv");
dotenv.config({path: __dirname + '/.env'});
const { API_URL, MNEMONIC } = process.env;

var mnemonic = MNEMONIC;
var api_url = API_URL;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: "0.8.20",
    defaultNetwork: "hardhat",  // change this to mumbai network when ready to deploy to polygon mumbai
    networks: {
        hardhat: {
            forking: {
                url: API_URL
            }
        },
        holesky: {
            network_id: 17000,
            url: process.env.HOLESKY_NODE_HTTP_URL,
            accounts: {
                mnemonic: mnemonic,
                path: "m/44'/60'/0'/0",
                initialIndex: 0,
                count: 20,
                passphrase: "",
            },
        },
        polygon: {
            url: api_url,
            accounts: {
                mnemonic: mnemonic,
                path: "m/44'/60'/0'/0",
                initialIndex: 0,
                count: 20,
                passphrase: "",
            },
        }, 
    },

    // for verifying source code contract
    etherscan: {
        apiKey: {
            polygonMumbai: "7E5R461T3GA968ANK43AJA4RW47PDBG79G", // victor's polygonscan api key
            polygon: "FG4F4RGNSRI24JFAWSTYK5DDK1JT9FABSM", // victor's polygonscan api key
            holesky: "ZPE9H8ZQDKTVXUK21U4HX85G7HUCHMWWA5" // jacob's eterscan api key
        }   
    },
    // enable sourcify verification 
    sourcify: {
        // Disabled by default
        // Doesn't need an API key
        enabled: true
      }
};
