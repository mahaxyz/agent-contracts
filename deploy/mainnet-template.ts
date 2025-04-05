import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, deployProxy, waitForTx } from "../scripts/utils";
import { roundTickToNearestTick } from "./utils";
import { computeTickPrice } from "./utils";
import { guessTokenAddress } from "../scripts/create2/guess-token-addr";
import { TokenLaunchpad, WAGMIEToken } from "../types";

export async function templateLaunchpad(
  hre: HardhatRuntimeEnvironment,
  deployer: string,
  proxyAdmin: string,
  adapterContract: string,
  launchpadContract: string,
  wethAddress: string,
  odosAddress: string,
  nftPositionManager: string,
  mahaAddress: string,
  feeDiscountAmount: bigint
) {
  const tokenD = await deployContract(
    hre,
    "WAGMIEToken",
    [],
    "TokenTemplateImpl"
  );
  const lockerD = await deployContract(
    hre,
    "FreeUniV3LPLocker",
    [nftPositionManager],
    "FreeUniV3LPLocker"
  );

  const adapterD = await deployProxy(
    hre,
    adapterContract,
    [],
    proxyAdmin,
    adapterContract,
    deployer,
    true // skip initialization
  );

  const launchpadD = await deployProxy(
    hre,
    launchpadContract,
    [
      adapterD.address,
      tokenD.address,
      deployer,
      wethAddress,
      mahaAddress,
      feeDiscountAmount,
    ],
    proxyAdmin,
    launchpadContract,
    deployer
  );

  const launchpad = await hre.ethers.getContractAt(
    "TokenLaunchpad",
    launchpadD.address
  );
  const tokenImpl = await hre.ethers.getContractAt(
    "WAGMIEToken",
    tokenD.address
  );
  const adapter = await hre.ethers.getContractAt(
    "ICLMMAdapter",
    adapterD.address
  );
  const locker = await hre.ethers.getContractAt(
    "FreeUniV3LPLocker",
    lockerD.address
  );

  const swappeD = await deployContract(
    hre,
    "Swapper",
    [adapterD.address, wethAddress, odosAddress],
    "Swapper"
  );
  const swapper = await hre.ethers.getContractAt("Swapper", swappeD.address);

  // initialize the contracts if they are not initialized
  if ((await tokenImpl.name()) !== "TEST") {
    await waitForTx(
      await tokenImpl.initialize({
        name: "TEST", // string name;
        symbol: "TEST", // string symbol;
        metadata: "TEST", // string metadata;
        adapter: adapterD.address, // address adapter;
      })
    );
  }

  return {
    adapter,
    launchpad,
    tokenImpl,
    swapper,
    locker,
  };
}

export const deployToken = async (
  hre: HardhatRuntimeEnvironment,
  deployer: string,
  name: string,
  symbol: string,
  priceOfETHinUSD: number,
  tickSpacing: number,
  metadata: string,
  startingMarketCapInUSD: number,
  endingMarketCapInUSD: number,
  fundingToken: string,
  launchpad: TokenLaunchpad,
  tokenImpl: WAGMIEToken,
  amountToBuy: bigint
) => {
  // calculate ticks
  const launchTick = computeTickPrice(
    startingMarketCapInUSD,
    priceOfETHinUSD,
    18,
    tickSpacing
  );
  const _graduationTick = computeTickPrice(
    endingMarketCapInUSD,
    priceOfETHinUSD,
    18,
    tickSpacing
  );
  const graduationTick =
    _graduationTick == launchTick ? launchTick + tickSpacing : _graduationTick;
  const upperMaxTick = roundTickToNearestTick(887220, tickSpacing); // Maximum possible tick value

  // guess the salt and computed address for the given token
  const { salt, computedAddress } = await guessTokenAddress(
    launchpad.target,
    tokenImpl.target,
    fundingToken,
    deployer,
    name,
    symbol
  );

  const data = {
    fundingToken,
    metadata,
    name,
    salt,
    symbol,
    launchTick,
    graduationTick,
    upperMaxTick,
    isFeeDiscounted: false,
  };

  const fee = await launchpad.creationFee();

  // create a launchpad token
  console.log("creating a launchpad token", data);
  console.log(
    "data",
    await launchpad.createAndBuy.populateTransaction(
      data,
      computedAddress,
      amountToBuy,
      {
        value: fee,
      }
    )
  );
  await waitForTx(
    await launchpad.createAndBuy(data, computedAddress, amountToBuy, {
      value: fee,
    })
  );

  return hre.ethers.getContractAt("WAGMIEToken", computedAddress);
};
