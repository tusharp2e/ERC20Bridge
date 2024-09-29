const { ethers, upgrades } = require("hardhat");

async function main() {
  // Deploying the UUPS upgradeable contract
  const ContractFactory = await ethers.getContractFactory("GiniBridgeProxy");

  console.log("Deploying UUPS Upgradeable Contract...");
  const contract = await upgrades.deployProxy(ContractFactory, ["0x5FbDB2315678afecb367f032d93F642f64180aa3", 1]);

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
