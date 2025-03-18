import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, waitForTx } from "../scripts/utils";
import { ZeroAddress } from "ethers";
import { guessTokenAddress } from "../scripts/create2/guess-token-addr";

// Helper function to compute the tick price for a given market cap in USD
const computeTickPrice = (
  marketCapInUSD: number,
  priceOfQuoteTokenInUSD: number,
  quoteSupplyDecimals: number,
  tickSpacing: number
) => {
  const e18 = 10n ** 18n;
  const marketCapInQuoteToken = marketCapInUSD / priceOfQuoteTokenInUSD;
  const totalSupply = 1000000000n * e18; // 1bn tokens
  const quoteSupply =
    (BigInt(Math.floor(marketCapInQuoteToken * 1000)) *
      10n ** BigInt(quoteSupplyDecimals)) /
    1000n;

  // Calculate sqrtPriceX96 following Uniswap v3 format
  const sqrtPriceRatio = (quoteSupply * e18) / totalSupply;
  const sqrtPriceX96 = BigInt(
    Math.floor(Math.sqrt(Number(sqrtPriceRatio)) * 2 ** 96)
  );
  const tick = Math.floor(
    Math.log(Number(sqrtPriceX96) / 2 ** 96) / Math.log(Math.sqrt(1.0001))
  );

  return roundTickToNearestTick(tick, tickSpacing);
};

// Helper function to round tick to the nearest tick spacing
const roundTickToNearestTick = (tick: number, tickSpacing: number) => {
  return Math.round(tick / tickSpacing) * tickSpacing;
};

async function main(hre: HardhatRuntimeEnvironment) {
  const [deployer] = await hre.ethers.getSigners();

  const tokenD = await deployContract(hre, "AgentToken", [], "AgentTokenImpl");
  const launchpadD = await deployContract(
    hre,
    "AgentLaunchpad",
    [],
    "AgentLaunchpad"
  );
  const mahaD = await deployContract(
    hre,
    "MockERC20",
    ["TEST MAHA", "TMAHA", 18],
    "MAHA"
  );

  const maha = await hre.ethers.getContractAt("MockERC20", mahaD.address);
  const launchpad = await hre.ethers.getContractAt(
    "AgentLaunchpad",
    launchpadD.address
  );
  const tokenImpl = await hre.ethers.getContractAt(
    "AgentToken",
    tokenD.address
  );

  const adapterD = await deployContract(
    hre,
    "RamsesAdapter",
    [],
    "RamsesAdapter"
  );

  const adapter = await hre.ethers.getContractAt(
    "RamsesAdapter",
    adapterD.address
  );

  // initialize the contracts if they are not initialized
  if ((await adapter.LAUNCHPAD()) !== launchpad.target) {
    await waitForTx(
      await adapter.initialize(
        launchpad.target,
        "0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42"
      )
    );

    await waitForTx(
      await tokenImpl.initialize({
        name: "", // string name;
        symbol: "", // string symbol;
        metadata: "", // string metadata;
        whitelisted: [deployer.address], // address[] fundManagers;
        limitPerWallet: 0, // uint256 limitPerWallet;
        adapter: ZeroAddress, // address adapter;
      })
    );
    await waitForTx(
      await launchpad.initialize(
        mahaD.address,
        adapterD.address,
        tokenD.address,
        deployer.address
      )
    );
  }

  // CONTRACTS ARE DEPLOYED; NOW WE CAN LAUNCH A NEW TOKEN

  // setup parameters
  const e18 = 1000000000000000000n;
  const name = "Test Token";
  const symbol = "TEST";
  const priceOfETHinUSD = 1800; // feed this with the price of ETH in USD
  const wethAddressOnLinea = "0xe5d7c2a44ffddf6b295a15c148167daaaf5cf34f";
  const tickSpacing = 200; // tick spacing for 1% fee
  const fee = 10000; // 1% fee
  const metadata = JSON.stringify({ image: "https://i.imgur.com/56aQaCV.png" });
  const limitPerWallet = 30000000n * e18; // 3% per wallet

  const startingMarketCapInUSD = 5000; // 5,000$ starting market cap
  const endingMarketCapInUSD = 69000; // 69,000$ ending market cap

  // calculate ticks
  const lowerTick = computeTickPrice(
    startingMarketCapInUSD,
    priceOfETHinUSD,
    18,
    tickSpacing
  );
  const upperTick = computeTickPrice(
    endingMarketCapInUSD,
    priceOfETHinUSD,
    18,
    tickSpacing
  );
  const upperMaxTick = roundTickToNearestTick(887220, tickSpacing); // Maximum possible tick value

  // mint some tokens
  await waitForTx(await maha.mint(deployer.address, 100000000000n * e18));

  // guess the salt and computed address for the given token
  const { salt, computedAddress } = await guessTokenAddress(
    launchpad.target,
    tokenImpl.target,
    wethAddressOnLinea,
    deployer.address,
    name,
    symbol
  );

  const data = {
    base: {
      fee,
      fundingToken: wethAddressOnLinea,
      limitPerWallet,
      metadata,
      name,
      salt,
      symbol,
    },
    liquidity: { lowerTick, upperTick, upperMaxTick },
  };

  // create a launchpad token
  console.log("creating a launchpad token");
  await waitForTx(await launchpad.create(data, computedAddress));
}

main.tags = ["TestDeploymentNile"];
export default main;
