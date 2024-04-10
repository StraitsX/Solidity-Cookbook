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
        version: "0.8.18",
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
    fuji: {
      accounts: [
        Wallet.fromMnemonic(process.env.DEPLOYER_MNEMONIC).privateKey,
        Wallet.fromMnemonic(process.env.ADMIN_MNEMONIC).privateKey,
      ],
      url: process.env.FUJI_C_CHAIN_NODE_HTTP_URL,
      network_id: 43113,
      saveDeployments: true,
      deploy: ["deploy/"],
      tags: ["fuji"],
    },
    dispatch: {
      accounts: [
        Wallet.fromMnemonic(process.env.DEPLOYER_MNEMONIC).privateKey,
        Wallet.fromMnemonic(process.env.ADMIN_MNEMONIC).privateKey,
      ],
      url: process.env.DISPATCH_TEST_NODE_HTTP_URL,
      network_id: 779672,
      saveDeployments: true,
      deploy: ["deploy/"],
      tags: ["dispatch"],
    },
    echo: {
      accounts: [
        Wallet.fromMnemonic(process.env.DEPLOYER_MNEMONIC).privateKey,
        Wallet.fromMnemonic(process.env.ADMIN_MNEMONIC).privateKey,
      ],
      url: process.env.ECHO_NODE_HTTP_URL,
      network_id: 173750,
      saveDeployments: true,
      deploy: ["deploy/"],
      tags: ["echo"],
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
      fuji: "fuji",
      dispatch: "dispatch",
      echo: "echo",
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
      {
        network: "fuji",
        chainId: 43113,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan",
          browserURL: "https://c-chain.snowtrace.io",
        },
      },
      {
        network: "dispatch",
        chainId: 779672,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/779672/etherscan",
          browserURL: "https://779672.testnet.routescan.io",
        },
      },
      {
        network: "echo",
        chainId: 173750,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/173750/etherscan",
          browserURL: "https://173750.testnet.routescan.io",
        },
      },
    ],
  },
};
