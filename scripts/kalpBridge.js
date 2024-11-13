const { ethers, upgrades } = require("hardhat");

async function main() {
  // Deploying the UUPS upgradeable contract
  const ContractFactory = await ethers.getContractFactory("KalpBridge");

  console.log("Deploying UUPS Upgradeable Contract...");
  // Pass ERC20 Token address as first parameter 
  const contract = await upgrades.deployProxy(ContractFactory, ["0x7E0a4b485aB538ED0dE3273B5bc5c81E8dfc6966", 1]);

  // Wait for contract to be deployed
   await contract.waitForDeployment();

   const proxyAddress = await contract.getAddress();
   const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
   console.log("proxy contract deployed at: ", proxyAddress);
   console.log("implementation deployed at: ", implementationAddress);
}

// Script to handle errors
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
