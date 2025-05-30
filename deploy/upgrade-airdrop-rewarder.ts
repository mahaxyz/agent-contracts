import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "hardhat";
import { waitForTx } from "../scripts/utils";

async function main(hre: HardhatRuntimeEnvironment) {
  // Check that we're on BSC
  if (hre.network.name !== "bsc") {
    throw new Error("This script is only for BSC network");
  }

  console.log("Starting AirdropRewarder upgrade script...");

  // Get deployer address
  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  console.log("Deployer address:", deployerAddress);
  
  // Get AirdropRewarder proxy address from deployments
  const airdropRewarderDeployment = await hre.deployments.get("AirdropRewarder-Proxy");
  const airdropRewarderProxyAddress = airdropRewarderDeployment.address;
  console.log("AirdropRewarder proxy address:", airdropRewarderProxyAddress);

  if (!airdropRewarderProxyAddress) {
    throw new Error("AirdropRewarder proxy address not found in deployments");
  }
  
  // Address of the proxy admin contract
  // Use the deployer as the proxy admin instead of mahaTreasury
  const proxyAdmin = deployerAddress;
  console.log("Proxy admin address:", proxyAdmin);

  console.log("Deploying new AirdropRewarder implementation...");
  const AirdropRewarderFactory = await ethers.getContractFactory("AirdropRewarder");
  const airdropRewarderImpl = await AirdropRewarderFactory.deploy();
  await airdropRewarderImpl.waitForDeployment();
  const airdropRewarderImplAddress = await airdropRewarderImpl.getAddress();
  console.log("New AirdropRewarder implementation deployed to:", airdropRewarderImplAddress);

  // Upgrade implementation for AirdropRewarder by calling upgradeToAndCall directly on the proxy
  // Since the deployer is the proxy admin, they have permission to call this function
  console.log("Upgrading AirdropRewarder implementation...");
  
  const proxyContract = await ethers.getContractAt("IMAHAProxy", airdropRewarderProxyAddress);
  
  // Call upgradeToAndCall with empty bytes for data parameter (no initialization)
  const upgradeTx = await proxyContract.upgradeToAndCall(airdropRewarderImplAddress, "0x");
  await waitForTx(upgradeTx);
  console.log("AirdropRewarder implementation upgraded successfully!");

  // Verify the new implementation on BSC Scan
  if (hre.network.name === "bsc") {
    console.log("Verifying new implementation on BSC Scan...");
    try {
      await hre.run("verify:verify", {
        address: airdropRewarderImplAddress,
        constructorArguments: [],
      });
      console.log("Verification successful!");
    } catch (error) {
      console.error("Verification failed:", error);
    }
  }

  console.log("Upgrade completed successfully!");
  console.log({
    AirdropRewarderProxy: airdropRewarderProxyAddress,
    NewImplementation: airdropRewarderImplAddress,
  });
}

main.tags = ["UpgradeAirdropRewarder"];
export default main; 