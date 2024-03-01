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

        snowtrace: {
            url: 'https://api.avax-test.network/ext/bc/C/rpc',
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
    // https://testnet.snowtrace.io/documentation/recipes/hardhat-verification
    etherscan: {
        apiKey: {
            snowtrace: "snowtrace", // apiKey is not required, just set a placeholder  
        },
        customChains: [
            {
              network: "snowtrace",
              chainId: 43113,
              urls: {
                apiURL: "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan",
                browserURL: "https://testnet.snowtrace.io"
              }
            }
        ]
    },
 
};
