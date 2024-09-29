require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    matic: {
    url: `https://rpc-amoy.polygon.technology`,
    accounts: [process.env.ACCOUNT_PRIVATE_KEY],
    },
},
};
