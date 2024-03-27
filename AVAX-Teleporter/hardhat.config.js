require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
const { Wallet } = require("ethers");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  sourcify: {
    enabled: true,
  },
  solidity: {
    compilers: [
      {
        version: "0.4.24",
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  namedAccounts: {
    deployer: 0,
    proxyAdmin: 1,
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      deploy: ["deploy/"],
    },
    mumbai: {
      accounts: [
        Wallet.fromMnemonic(process.env.DEPLOYER_MNEMONIC).privateKey,
        Wallet.fromMnemonic(process.env.ADMIN_MNEMONIC).privateKey,
      ],
      url: process.env.POLYGON_MUMBAI_NODE_HTTP_URL,
      network_id: 80001,
      saveDeployments: true,
      deploy: ["deploy/"],
      tags: ["mumbai"],
    },
    polygon: {
      accounts: [
        Wallet.fromMnemonic(process.env.DEPLOYER_MNEMONIC).privateKey,
        Wallet.fromMnemonic(process.env.ADMIN_MNEMONIC).privateKey,
      ],
      url: process.env.POLYGON_MAINNET_NODE_HTTP_URL,
      network_id: 137,
      saveDeployments: true,
      deploy: ["deploy/"],
      tags: ["mainnet"],
    },
    sepolia: {
      accounts: [
        Wallet.fromMnemonic(process.env.DEPLOYER_MNEMONIC).privateKey,
        Wallet.fromMnemonic(process.env.ADMIN_MNEMONIC).privateKey,
      ],
      url: process.env.SEPOLIA_NODE_HTTP_URL,
      network_id: 11155111,
      saveDeployments: true,
      deploy: ["deploy/"],
      tags: ["sepolia"],
    },
    ethereum: {
      accounts: [
        Wallet.fromMnemonic(process.env.DEPLOYER_MNEMONIC).privateKey,
        Wallet.fromMnemonic(process.env.ADMIN_MNEMONIC).privateKey,
      ],
      url: process.env.ETHEREUM_NODE_HTTP_URL,
      network_id: 1,
      saveDeployments: true,
      deploy: ["deploy/"],
      tags: ["ethereum"],
    },
    holesky: {
      accounts: [
        Wallet.fromMnemonic(process.env.DEPLOYER_MNEMONIC).privateKey,
        Wallet.fromMnemonic(process.env.ADMIN_MNEMONIC).privateKey,
      ],
      url: process.env.HOLESKY_NODE_HTTP_URL,
      network_id: 17000,
      saveDeployments: true,
      deploy: ["deploy/"],
      tags: ["holesky"],
    },
    orcSubnet: {
      accounts: [
        Wallet.fromMnemonic(process.env.DEPLOYER_MNEMONIC).privateKey,
        Wallet.fromMnemonic(process.env.ADMIN_MNEMONIC).privateKey,
      ],
      url: process.env.ORC_SUBNET_NODE_HTTP_URL,
      network_id: 234560,
      saveDeployments: true,
      deploy: ["deploy/"],
      tags: ["orcSubnet"],
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  etherscan: {
    apiKey: {
      mumbai: process.env.MUMBAI_SCAN_API_KEY,
      polygon: process.env.POLYGON_SCAN_API_KEY,
      sepolia: process.env.SEPOLIA_SCAN_API_KEY,
      ethereum: process.env.ETHER_SCAN_API_KEY,
      holesky: process.env.ETHER_SCAN_API_KEY,
    },
    customChains: [
      {
        network: "mumbai",
        chainId: 80001,
        urls: {
          apiURL: "https://api-testnet.polygonscan.com/api",
          browserURL: "https://mumbai.polygonscan.com",
        },
      },
      {
        network: "polygon",
        chainId: 137,
        urls: {
          apiURL: "https://api.polygonscan.com/api",
          browserURL: "https://polygonscan.com",
        },
      },
      {
        network: "sepolia",
        chainId: 11155111,
        urls: {
          apiURL: "https://api-sepolia.etherscan.io/api",
          browserURL: "https://sepolia.etherscan.io/",
        },
      },
      {
        network: "ethereum",
        chainId: 1,
        urls: {
          apiURL: "https://api.etherscan.io/api",
          browserURL: "https://etherscan.io/",
        },
      },
      {
        network: "holesky",
        chainId: 17000,
        urls: {
          apiURL: "https://api-holesky.etherscan.io/api",
          browserURL: "https://holesky.etherscan.io/",
        },
      },
    ],
  },
};
