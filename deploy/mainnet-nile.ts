import { computeTickPrice, roundTickToNearestTick } from "./utils";
import { guessTokenAddress } from "../scripts/create2/guess-token-addr";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { RamsesAdapter } from "../types";
import { deployToken, templateLaunchpad } from "./mainnet-template";
import { deployContract, waitForTx } from "../scripts/utils";

async function main(hre: HardhatRuntimeEnvironment) {
  const deployer = "0xb0a8169d471051130cc458e4862b7fd0008cdf82";
  const proxyAdmin = "0x7202136d70026DA33628dD3f3eFccb43F62a2469";
  const wethAddressOnLinea = "0xe5d7c2a44ffddf6b295a15c148167daaaf5cf34f";
  const odosAddressOnLinea = "0x2d8879046f1559E53eb052E949e9544bCB72f414";

  const { adapter, launchpad, tokenImpl } = await templateLaunchpad(
    hre,
    deployer,
    proxyAdmin,
    "RamsesAdapter",
    "TokenLaunchpadLinea",
    wethAddressOnLinea,
    odosAddressOnLinea
  );

  // initialize the contracts if they are not initialized
  const adapterNile = adapter as RamsesAdapter;
  if ((await adapterNile.launchpad()) !== launchpad.target) {
    await waitForTx(
      await adapterNile.initialize(
        launchpad.target,
        "0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42",
        "0xAAAE99091Fbb28D400029052821653C1C752483B",
        wethAddressOnLinea
      )
    );
  }

  // CONTRACTS ARE DEPLOYED; NOW WE CAN LAUNCH A NEW TOKEN

  // setup parameters
  const name = "Test Token";
  const symbol = "TEST";
  const tickSpacing = 500; // tick spacing for 1% fee
  const metadata = JSON.stringify({ image: "https://i.imgur.com/56aQaCV.png" });
  const limitPerWallet = 1000000000n * 1000000000000000000n; // 100% per wallet

  const token1 = await deployToken(
    hre,
    deployer,
    name,
    symbol,
    1800, // price of token in USD
    tickSpacing,
    metadata,
    limitPerWallet,
    5000, // 5,000$ starting market cap
    69000, // 69,000$ ending market cap
    wethAddressOnLinea,
    launchpad,
    tokenImpl,
    0n
  );

  console.log("Token deployed at", token1.target);

  const shouldMock = true;
  if (shouldMock) {
    const mahaD = await deployContract(
      hre,
      "MockERC20",
      ["TEST MAHA", "TMAHA", 18],
      "MAHA"
    );

    const maha = await hre.ethers.getContractAt("MockERC20", mahaD.address);

    await waitForTx(await maha.mint(deployer, 1000000000000000000000000n));
    await waitForTx(
      await maha.approve(launchpad.target, 1000000000000000000000000n)
    );

    const token2 = await deployToken(
      hre,
      deployer,
      name,
      symbol,
      1, // price of token in USD
      tickSpacing,
      metadata,
      limitPerWallet,
      5000, // 5,000$ starting market cap
      69000, // 69,000$ ending market cap
      mahaD.address,
      launchpad,
      tokenImpl,
      100000000000000000000n
    );

    console.log("Token deployed at", token2.target);
  }
}

main.tags = ["DeploymentNile"];
export default main;
