import { ethers } from "hardhat";

async function main() {
  const registry = "0x8d72A78B1F13FB73Cf6dfd30C94f15364E9A5163";
  const pool = "0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16";
  const router = "0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16";
  const Escrow = await ethers.getContractFactory("HWEscrow");
  const escrow = await Escrow.deploy(registry, pool, router);
  await escrow.deployed();
  console.log("Escrow deployed to:", escrow.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
