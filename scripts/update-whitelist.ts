import { Client as notion_Client } from "@notionhq/client";
import { Client as redis_Client } from "redis-om";
import { ethers } from "hardhat";
import { MerkleTree } from "merkletreejs";
const keccak256 = require("keccak256");
import * as dotenv from "dotenv";
import { QueryDatabaseResponse } from "@notionhq/client/build/src/api-endpoints";
dotenv.config();

const main = async () => {
  const redis_client = new redis_Client();
  if (!redis_client.isOpen()) {
    await redis_client.open(process.env.REDIS_URL);
  }
  let queue = [];
  const notion_client = new notion_Client({ auth: process.env.NOTION_KEY });
  const response = await notion_client.databases.query({ database_id: process.env.NOTION_DATABASE_ID! });
  for (let i = 0; i < response.results.length; i++) {
    const page_response: any = await notion_client.pages.retrieve({ page_id: response.results[i].id });
    if (page_response.properties.Status.select.name === "Queued") {
      queue.push(page_response.properties.Address.title[0].plain_text);
    }
  }
  // await updateContract(queue);
  await updateDB(redis_client, "whitelist", queue);
  await updateNotionPages(notion_client, response);
  redis_client.close();
};
const updateDB = async (redis_client: redis_Client, key: string, items: any) => {
  for (let i = 0; i < items.length; i++) {
    await redis_client.execute(["RPUSH", key, items[i]]);
  }
};
const updateNotionPages = async (notion_client: notion_Client, response: QueryDatabaseResponse) => {
  for (let i = 0; i < response.results.length; i++) {
    const update_response = await notion_client.pages.update({
      page_id: response.results[i].id,
      properties: {
        Status: {
          select: {
            id: "b5a615ae-0db7-429c-94cf-a3971b8b2f15",
            name: "Processed",
            color: "green",
          },
        },
      },
    });
  }
};
const updateContract = async (queue: string[]) => {
  const NFTContract = await ethers.getContractFactory("NFT");
  const contract = NFTContract.attach(process.env.HONESTWORK_NFT_ADDRESS!);
  const leaves = queue.map((address) => keccak256(address));
  const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
  const root = tree.getHexRoot();
  const tx = await contract.setWhitelistRoot(root);
  console.log("Transaction hash: ", tx.hash);
  await tx.wait();
  console.log("Transaction confirmed");
};
main().catch((error) => {
  console.error(error);
  console.log("Exiting");
  process.exitCode = 1;
});
