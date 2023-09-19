import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("Fairsharing Test", function () {
  const baseURI = "https://api-preview.frenart.io/member/governance/metaData/";

  async function deployFixture() {
    const [owner, signer] = await ethers.getSigners();
    const projectFactory = await ethers.getContractFactory("Project");
    const project = await projectFactory.deploy();

    const projectTokenFactory = await ethers.getContractFactory("ProjectToken");
    const projectToken = await projectTokenFactory.deploy();

    // upgrade
    {
      // Governance NFT
      const factory = await ethers.getContractFactory("ProjectRegistry");
      const instance = await upgrades.deployProxy(factory, [
        owner.address,
        signer.address,
        await project.getAddress(),
        await projectToken.getAddress(),
      ]);

      return {
        projectRegister: instance,
        owner,
      };
    }
  }

  it("#0 - Should set the right owner", async function () {
    await loadFixture(deployFixture);
    const { projectRegister, owner } = await loadFixture(deployFixture);
    expect(await projectRegister.owner()).to.equal(owner.address);
  });

  it("#1 - Upgrade", async function () {
    const { projectRegister, owner } = await loadFixture(deployFixture);

    const governanceFactoryV2 = await ethers.getContractFactory("ProjectRegistryV2");

    const upgraded = await upgrades.upgradeProxy(
      await projectRegister.getAddress(),
      governanceFactoryV2
    );

    expect(await upgraded.version()).to.equal("1.0.1");
  });
});
