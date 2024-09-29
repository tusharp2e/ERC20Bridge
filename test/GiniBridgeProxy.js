const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers, upgrades } = require('hardhat');

describe("Lock", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearLockFixture() {
    const INITIAL_SUPPLY = BigInt(100000000000000000000);
    const initialSupply = INITIAL_SUPPLY;

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const GLDToken = await ethers.getContractFactory("GLDToken");
    const gldToken = await GLDToken.deploy(GLDToken, { initialSupply: initialSupply });

    const GiniBridgeProxy = await ethers.getContractFactory("GiniBridgeProxy");
    giniTokenProxy = await upgrades.deployProxy(GiniBridgeProxy, [gldToken.target, 1])
    console.log(giniTokenProxy.target)    
    return { gldToken, giniTokenProxy, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { giniTokenProxy, owner } = await loadFixture(deployOneYearLockFixture);
      console.log(giniTokenProxy.owner())
      expect(await giniTokenProxy.owner()).to.equal(owner);
    });
  });

});
