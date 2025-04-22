import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, deployProxy, waitForTx } from "../scripts/utils";
import { roundTickToNearestTick } from "./utils";
import { computeTickPrice } from "./utils";
import { guessTokenAddress } from "../scripts/create2/guess-token-addr";
import { ICLMMAdapter, ITokenLaunchpad, TokenLaunchpad } from "../types";

export async function templateLaunchpad(
  hre: HardhatRuntimeEnvironment,
  deployer: string,
  proxyAdmin: string,
  launchpadContract: string,
  wethAddress: string,
  odosAddress: string,
  mahaAddress: string,
  feeDiscountAmount: bigint
) {
  const launchpadD = await deployProxy(
    hre,
    launchpadContract,
    [deployer, wethAddress, mahaAddress, feeDiscountAmount],
    proxyAdmin,
    launchpadContract,
    deployer
  );

  const launchpad = await hre.ethers.getContractAt(
    "TokenLaunchpad",
    launchpadD.address
  );

  const swappeD = await deployContract(
    hre,
    "Swapper",
    [wethAddress, odosAddress, launchpadD.address],
    "Swapper"
  );
  const swapper = await hre.ethers.getContractAt("Swapper", swappeD.address);

  return {
    launchpad,
    swapper,
  };
}

export async function deployAdapter(
  hre: HardhatRuntimeEnvironment,
  deployer: string,
  proxyAdmin: string,
  adapterContract: string,
  launchpad: TokenLaunchpad
) {
  const adapterD = await deployProxy(
    hre,
    adapterContract,
    [],
    proxyAdmin,
    adapterContract,
    deployer,
    true
  );

  const adapter = await hre.ethers.getContractAt(
    "ICLMMAdapter",
    adapterD.address
  );

  if (!(await launchpad.adapters(adapter))) {
    console.log("whitelisting adapter");
    await waitForTx(await launchpad.toggleAdapter(adapter));
  }

  return adapter;
}

export const deployToken = async (
  hre: HardhatRuntimeEnvironment,
  adapter: ICLMMAdapter,
  deployer: string,
  name: string,
  symbol: string,
  priceOfETHinUSD: number,
  tickSpacing: number,
  fee: bigint,
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

  const data: ITokenLaunchpad.CreateParamsStruct = {
    adapter: adapter.target,
    creatorAllocation: 0,
    fundingToken,
    isPremium: false,
    launchPoolAmounts: [],
    launchPools: [],
    metadata,
    name,
    salt,
    symbol,
    valueParams: {
      fee,
      graduationLiquidity: 800000000n,
      graduationTick,
      launchTick,
      tickSpacing,
      upperMaxTick,
    },
  };

  const creationFee = await launchpad.creationFee();
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
        value: creationFee + dust,
      }
    )
  );
  await waitForTx(
    await launchpad.createAndBuy(data, computedAddress, amountToBuy, {
      value: creationFee + dust,
    })
  );

  return hre.ethers.getContractAt("WAGMIEToken", computedAddress);
};
