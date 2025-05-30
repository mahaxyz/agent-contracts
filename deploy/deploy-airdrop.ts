import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "hardhat";
import { deployProxy } from "../scripts/utils";

async function main(hre: HardhatRuntimeEnvironment) {
  // Check that we're on BSC
  if (hre.network.name !== "bsc") {
    throw new Error("This script is only for BSC network");
  }

  console.log("Starting deployment of AirdropRewarder...");

  // Get deployer address
  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  console.log("Deployer address:", deployerAddress);

  // Get TokenLaunchpadBSC-Proxy address from deployments
  const tokenLaunchpadDeployment = await hre.deployments.get("TokenLaunchpadBSC-Proxy");
  const tokenLaunchpadAddress = tokenLaunchpadDeployment.address;
  console.log("TokenLaunchpadBSC address:", tokenLaunchpadAddress);

  if(!tokenLaunchpadAddress) {
    throw new Error("TokenLaunchpadBSC address is not set");
  }
  
  // Use deployer as proxy admin
  const proxyAdmin = deployerAddress;
  console.log("Proxy admin:", proxyAdmin);
  
  const airdropRewarder = await deployProxy(
    hre,
    "AirdropRewarder",
    [tokenLaunchpadAddress],
    proxyAdmin,
    "AirdropRewarder",
    deployerAddress
  );
  console.log("AirdropRewarder proxy deployed to:", airdropRewarder.address);
}

main.tags = ["DeployAirdrop"];
export default main;
