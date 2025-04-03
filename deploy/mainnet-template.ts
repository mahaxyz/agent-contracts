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
  odosAddress: string
) {
  const tokenD = await deployContract(
    hre,
    "WAGMIEToken",
    [],
    "TokenTemplateImpl"
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
    [adapterD.address, tokenD.address, deployer, wethAddress, odosAddress],
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

  // initialize the contracts if they are not initialized
  if ((await tokenImpl.name()) !== "TEST") {
    await waitForTx(
      await tokenImpl.initialize({
        name: "TEST", // string name;
        symbol: "TEST", // string symbol;
        metadata: "TEST", // string metadata;
        limitPerWallet: 1000000000000000000n, // uint256 limitPerWallet;
        adapter: adapterD.address, // address adapter;
      })
    );
  }

  return {
    adapter,
    launchpad,
    tokenImpl,
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
  limitPerWallet: bigint,
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
    limitPerWallet,
    metadata,
    name,
    salt,
    symbol,
    launchTick,
    graduationTick,
    upperMaxTick,
  };

  // create a launchpad token
  console.log("creating a launchpad token", data);
  console.log(
    "data",
    await launchpad.createAndBuy.populateTransaction(
      data,
      computedAddress,
      amountToBuy,
      {
        value: 100000000000000n,
      }
    )
  );
  await waitForTx(
    await launchpad.createAndBuy(data, computedAddress, amountToBuy, {
      value: 100000000000000n,
    })
  );

  return hre.ethers.getContractAt("WAGMIEToken", computedAddress);
};
