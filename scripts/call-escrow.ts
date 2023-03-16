import { ethers } from "hardhat";

async function main() {
    //define already deployed escrow contract
    const escrowAddress = "0x4258376797A51c5Db1C0f590299202d2b914662D";
    const escrow = await ethers.getContractAt("HWEscrow", escrowAddress);
    console.log(await escrow.getAllDeals()); 
}

main()