import { Client as notion_Client } from "@notionhq/client";
import { ethers } from "hardhat";
import { MerkleTree } from "merkletreejs";
import * as dotenv from "dotenv";
import { QueryDatabaseResponse } from "@notionhq/client/build/src/api-endpoints";
import { MongoClient } from 'mongodb';
import Keccak256 from "keccak256";
dotenv.config();

const main = async () => {
  const mongodb_client = new MongoClient(process.env.MONGODB_URI!);
  await mongodb_client.connect();
  let queue = [];
  const notion_client = new notion_Client({ auth: process.env.NOTION_KEY });
  const response = await notion_client.databases.query({ database_id: process.env.NOTION_AMBASSADOR_DATABASE_ID! });
  for (let i = 0; i < response.results.length; i++) {
    const page_response: any = await notion_client.pages.retrieve({ page_id: response.results[i].id });
    if (page_response.properties.Address.title.length > 0) {
      queue.push(page_response.properties.Address.title[0].plain_text);
    }
  }
  console.log("Queue: ", queue);
  await updateContract(queue);
  console.log("Updated contract.");
  await updateDB(mongodb_client, queue);
  console.log("Updated db.");
  await updateNotionPages(notion_client, response);
  console.log("Updated notion.");
  mongodb_client.close()
};
const updateDB = async (mongodb_client: MongoClient, queue: string[]) => {
  const database = mongodb_client.db("honestwork-cluster");
  const collection = database.collection("ambassador-whitelists");
  const query = {
    addresses: queue,
    createdat: new Date().getTime(),
  }
  await collection.insertOne(query);
};
const updateNotionPages = async (notion_client: notion_Client, response: QueryDatabaseResponse) => {
  for (let i = 0; i < response.results.length; i++) {
    await notion_client.pages.update({
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
  const NFTContract = await ethers.getContractFactory("StarterNFT");
  const contract = NFTContract.attach(process.env.HONESTWORK_STARTER_NFT_ADDRESS!);
  const leaves = queue.map((address) => Keccak256(address));
  const tree = new MerkleTree(leaves, Keccak256, { sortPairs: true });
  const root = tree.getHexRoot();
  console.log("Root: ", root);
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
