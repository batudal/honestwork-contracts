import { ethers } from "hardhat";

async function main() {
  const registry = "0x8d72A78B1F13FB73Cf6dfd30C94f15364E9A5163";
  const fee = 5;

  const Escrow = await ethers.getContractFactory("HWEscrow");
  const escrow = await Escrow.deploy(registry, fee);
  await escrow.deployed();
  console.log("Escrow deployed to:", escrow.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
