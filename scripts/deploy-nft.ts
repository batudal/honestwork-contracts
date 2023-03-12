import { ethers } from "hardhat";

async function main() {
  const NFT = await ethers.getContractFactory("HonestWorkNFT");
  const nft = await NFT.deploy("_", []);
  await nft.deployed();
  console.log("NFT deployed to:", nft.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
