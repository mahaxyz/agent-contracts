import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract } from "../scripts/utils";
import assert from "assert";
async function main(hre: HardhatRuntimeEnvironment) {
  assert(hre.network.name === "bsc", "This script is only for BSC");

  const name = "WAGMIE Medalions";
  const symbol = "WAGMIE-M";
  const baseURI = "https://prod-api.wagmie.com/nft-tokenuri/";

  const achievementNFTD = await deployContract(
    hre,
    "AchievementNFT",
    [name, symbol, baseURI],
    "AchievementNFT"
  );

  console.log("AchievementNFT deployed to:", achievementNFTD.address);
}

main.tags = ["WAGMIE-NFT"];
export default main;
