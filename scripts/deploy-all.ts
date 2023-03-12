import { ethers } from "hardhat";

async function main() {
  const Registry = await ethers.getContractFactory("HWRegistry");
  const registry = await Registry.deploy();
  await registry.deployed();
  console.log("Registry deployed to:", registry.address);

  const Escrow = await ethers.getContractFactory("HWEscrow");
  const escrow = await Escrow.deploy(registry.address, 5);
  await escrow.deployed();
  console.log("Escrow deployed to:", escrow.address);

  const Listing = await ethers.getContractFactory("HWListing");
  const listing = await Listing.deploy(registry.address);
  await listing.deployed();
  console.log("Listing deployed to:", listing.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
