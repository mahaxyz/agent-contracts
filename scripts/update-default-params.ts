import { parseEther } from "ethers";
import hre from "hardhat";
import { computeTickPrice } from "../deploy/utils";
import { waitForTx } from "./utils";

async function main() {
  const launchpadDeployer = await hre.deployments.get("TokenLaunchpadBSC");
  const launchpad = await hre.ethers.getContractAt(
    "TokenLaunchpad",
    launchpadDeployer.address
  );

  const adapterPcs = await hre.deployments.get("PancakeAdapter");
  const adapterThena = await hre.deployments.get("ThenaAdapter");
  const wbnbAddressOnBsc = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";

  const bnbPrice = 618;

  await waitForTx(
    await launchpad.setDefaultValueParams(
      wbnbAddressOnBsc,
      adapterPcs.address,
      {
        launchTick: computeTickPrice(5000, bnbPrice, 18, 200),
        graduationTick: computeTickPrice(69000, bnbPrice, 18, 200),
        upperMaxTick: 887_000,
        fee: 10000,
        tickSpacing: 200,
        graduationLiquidity: parseEther("800000000"),
      }
    )
  );
  await waitForTx(
    await launchpad.setDefaultValueParams(
      wbnbAddressOnBsc,
      adapterThena.address,
      {
        launchTick: computeTickPrice(5000, bnbPrice, 18, 60),
        graduationTick: computeTickPrice(69000, bnbPrice, 18, 60),
        upperMaxTick: 88740,
        fee: 3000,
        tickSpacing: 60,
        graduationLiquidity: parseEther("800000000"),
      }
    )
  );
}

main().catch(console.error);
