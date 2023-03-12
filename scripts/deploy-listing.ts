import { ethers } from "hardhat";

async function main() {
  const registry = "0x8d72A78B1F13FB73Cf6dfd30C94f15364E9A5163";

  const Listing = await ethers.getContractFactory("HWListing");
  const listing = await Listing.deploy(registry);
  await listing.deployed();
  console.log("Listing deployed to:", listing.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
