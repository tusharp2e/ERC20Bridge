const { ethers, upgrades } = require("hardhat");

async function main() {
  // Define constructor parameters if necessary
  const initialParam1 = "Initial parameter"; // Example parameter, adjust as needed

  // Deploying the UUPS upgradeable contract
  const ContractFactory = await ethers.getContractFactory("GiniBridgeProxy");

  console.log("Deploying UUPS Upgradeable Contract...");
  const contract = await upgrades.deployProxy(ContractFactory, ["0x5FbDB2315678afecb367f032d93F642f64180aa3", 1]);

  // Wait for contract to be deployed
  await contract.deployed();

  console.log("Contract deployed to:", contract.address);

  // Now you can interact with the contract
  // Example: calling a function on the contract
  // await contract.someFunction();
}

// Script to handle errors
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
