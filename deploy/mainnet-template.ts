import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, deployProxy, waitForTx } from "../scripts/utils";
import { roundTickToNearestTick } from "./utils";
import { computeTickPrice } from "./utils";
import { guessTokenAddress } from "../scripts/create2/guess-token-addr";
import { TokenLaunchpad } from "../types";

export async function templateLaunchpad(
  hre: HardhatRuntimeEnvironment,
  deployer: string,
  proxyAdmin: string,
  adapterContract: string,
  launchpadContract: string,
  launchpoolTokens: string[],
  wethAddress: string,
  odosAddress: string,
  mahaAddress: string,
  feeDiscountAmount: bigint
) {
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
    [adapterD.address, deployer, wethAddress, mahaAddress, feeDiscountAmount],
    proxyAdmin,
    launchpadContract,
    deployer
  );

  const launchpoolD = await deployProxy(
    hre,
    "Launchpool",
    [adapterD.address, deployer, wethAddress, mahaAddress, feeDiscountAmount],
    proxyAdmin,
    launchpadContract,
    deployer
  );

  const launchpad = await hre.ethers.getContractAt(
    "TokenLaunchpad",
    launchpadD.address
  );

  const adapter = await hre.ethers.getContractAt(
    "ICLMMAdapter",
    adapterD.address
  );

  const swappeD = await deployContract(
    hre,
    "Swapper",
    [adapterD.address, wethAddress, odosAddress, launchpadD.address],
    "Swapper"
  );
  const swapper = await hre.ethers.getContractAt("Swapper", swappeD.address);

  return {
    adapter,
    launchpad,
    swapper,
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

  // get the bytecode for the WAGMIEToken
  const wagmie = await hre.ethers.getContractFactory("WAGMIEToken");

  // guess the salt and computed address for the given token
  const { salt, computedAddress } = await guessTokenAddress(
    launchpad.target,
    wagmie.bytecode, // tokenImpl.target,
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
    launchTick: -171_000,
    graduationTick: -170_800,
    upperMaxTick: 887_200,
    isFeeDiscounted: false,
  };

  const fee = await launchpad.creationFee();
  const dust = 10000000000000n;

  // create a launchpad token
  console.log("creating a launchpad token", data);
  console.log(
    "data",
    await launchpad.createAndBuy.populateTransaction(
      data,
      computedAddress,
      amountToBuy,
      {
        value: fee + dust,
      }
    )
  );
  await waitForTx(
    await launchpad.createAndBuy(data, computedAddress, amountToBuy, {
      value: fee + dust,
    })
  );

  return hre.ethers.getContractAt("WAGMIEToken", computedAddress);
};
