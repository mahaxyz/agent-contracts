import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, waitForTx } from "../scripts/utils";
import { guessTokenAddress } from "../scripts/create2/guess-token-addr";

async function main(hre: HardhatRuntimeEnvironment) {
  const [deployer] = await hre.ethers.getSigners();

  const tokenD = await deployContract(
    hre,
    "WAGMIEToken",
    [],
    "TokenTemplateImpl"
  );
  const launchpadD = await deployContract(
    hre,
    "TokenLaunchpadLinea",
    [],
    "TokenLaunchpadLinea"
  );
  const mahaD = await deployContract(
    hre,
    "MockERC20",
    ["TEST MAHA", "TMAHA", 18],
    "MAHA"
  );

  const maha = await hre.ethers.getContractAt("MockERC20", mahaD.address);
  const launchpad = await hre.ethers.getContractAt(
    "TokenLaunchpadLinea",
    launchpadD.address
  );
  const tokenImpl = await hre.ethers.getContractAt(
    "WAGMIEToken",
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
    await waitForTx(
      await launchpad.initialize(
        adapterD.address,
        tokenD.address,
        deployer.address,
        "0xe5d7c2a44ffddf6b295a15c148167daaaf5cf34f"
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
  const limitPerWallet = 1000000000n * e18; // 100% per wallet

  const startingMarketCapInUSD = 68000; // 5,000$ starting market cap
  const endingMarketCapInUSD = 69000; // 69,000$ ending market cap

  // calculate ticks
  const launchTick = computeTickPrice(
    startingMarketCapInUSD,
    priceOfETHinUSD,
    18,
    tickSpacing
  );
  const graduationTick = computeTickPrice(
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
    fee,
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
  console.log("creating a launchpad token");
  await waitForTx(
    await launchpad.createAndBuy(data, computedAddress, 0, {
      value: 100000000000000n,
    })
  );
}

main.tags = ["TestDeploymentNile"];
export default main;
