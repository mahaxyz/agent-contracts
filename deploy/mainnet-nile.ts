import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, deployProxy, waitForTx } from "../scripts/utils";
import { guessTokenAddress } from "../scripts/create2/guess-token-addr";
import { computeTickPrice, roundTickToNearestTick } from "./utils";

async function main(hre: HardhatRuntimeEnvironment) {
  const deployer = "0xb0a8169d471051130cc458e4862b7fd0008cdf82";
  const proxyAdmin = "0x7202136d70026DA33628dD3f3eFccb43F62a2469";

  const tokenD = await deployContract(
    hre,
    "TokenTemplate",
    [],
    "TokenTemplateImpl"
  );

  const adapterD = await deployProxy(
    hre,
    "RamsesAdapter",
    [],
    proxyAdmin,
    "RamsesAdapter",
    deployer,
    true // skip initialization
  );

  const launchpadD = await deployProxy(
    hre,
    "TokenLaunchpadLinea",
    [
      adapterD.address,
      tokenD.address,
      deployer,
      "0xe5d7c2a44ffddf6b295a15c148167daaaf5cf34f",
    ],
    proxyAdmin,
    "TokenLaunchpadLinea",
    deployer
  );

  const launchpad = await hre.ethers.getContractAt(
    "TokenLaunchpadLinea",
    launchpadD.address
  );
  const tokenImpl = await hre.ethers.getContractAt(
    "TokenTemplate",
    tokenD.address
  );
  const adapter = await hre.ethers.getContractAt(
    "RamsesAdapter",
    adapterD.address
  );

  // initialize the contracts if they are not initialized
  if ((await adapter.launchpad()) !== launchpad.target) {
    await waitForTx(
      await adapter.initialize(
        launchpad.target,
        "0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42",
        "0xAAAE99091Fbb28D400029052821653C1C752483B",
        "0xe5d7c2a44ffddf6b295a15c148167daaaf5cf34f"
      )
    );

    await waitForTx(
      await tokenImpl.initialize({
        name: "", // string name;
        symbol: "", // string symbol;
        metadata: "", // string metadata;
        limitPerWallet: 1000000000000000000n, // uint256 limitPerWallet;
        adapter: adapterD.address, // address adapter;
      })
    );
  }

  // CONTRACTS ARE DEPLOYED; NOW WE CAN LAUNCH A NEW TOKEN

  // setup parameters
  const e18 = 1000000000000000000n;
  const name = "Test Token";
  const symbol = "TEST";
  const priceOfETHinUSD = 1800; // feed this with the price of ETH in USD
  const wethAddressOnLinea = "0xe5d7c2a44ffddf6b295a15c148167daaaf5cf34f";
  const tickSpacing = 500; // tick spacing for 1% fee
  const metadata = JSON.stringify({ image: "https://i.imgur.com/56aQaCV.png" });
  const limitPerWallet = 1000000000n * e18; // 100% per wallet

  const startingMarketCapInUSD = 67000; // 5,000$ starting market cap
  const endingMarketCapInUSD = 69000; // 69,000$ ending market cap

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
    wethAddressOnLinea,
    deployer,
    name,
    symbol
  );

  const data = {
    fundingToken: wethAddressOnLinea,
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
  await waitForTx(
    await launchpad.createAndBuy(data, computedAddress, 0, {
      value: 100000000000000n,
    })
  );
}

main.tags = ["DeploymentNile"];
export default main;
