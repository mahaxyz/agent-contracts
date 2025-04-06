import { computeTickPrice, roundTickToNearestTick } from "./utils";
import { guessTokenAddress } from "../scripts/create2/guess-token-addr";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { RamsesAdapter } from "../types";
import { deployToken, templateLaunchpad } from "./mainnet-template";
import { deployContract, waitForTx } from "../scripts/utils";

async function main(hre: HardhatRuntimeEnvironment) {
  const deployer = "0x1F09Ec21d7fd0A21879b919bf0f9C46e6b85CA8b";
  const proxyAdmin = "0x7202136d70026DA33628dD3f3eFccb43F62a2469";
  const wethAddressOnLinea = "0xe5d7c2a44ffddf6b295a15c148167daaaf5cf34f";
  const odosAddressOnLinea = "0x2d8879046f1559E53eb052E949e9544bCB72f414";
  const nftPositionManager = "0xAAA78E8C4241990B4ce159E105dA08129345946A";
  const mahaAddress = "0x6a661312938d22a2a0e27f585073e4406903990a";
  const e18 = 10n ** 18n;
  const feeDiscountAmount = 1000n * e18; // 100%

  const { adapter, launchpad, tokenImpl, locker } = await templateLaunchpad(
    hre,
    deployer,
    proxyAdmin,
    "RamsesAdapter",
    "TokenLaunchpadLinea",
    wethAddressOnLinea,
    odosAddressOnLinea,
    mahaAddress,
    feeDiscountAmount
  );

  // initialize the contracts if they are not initialized
  const adapterNile = adapter as RamsesAdapter;
  if ((await adapterNile.launchpad()) !== launchpad.target) {
    await waitForTx(
      await adapterNile.initialize(
        launchpad.target,
        "0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42",
        "0xAAAE99091Fbb28D400029052821653C1C752483B",
        wethAddressOnLinea,
        locker.target,
        nftPositionManager
      )
    );
  }

  // CONTRACTS ARE DEPLOYED; NOW WE CAN LAUNCH A NEW TOKEN

  // setup parameters
  const name = "Test Token";
  const symbol = "TEST";
  const tickSpacing = 500; // tick spacing for 2% fee
  const metadata = JSON.stringify({ image: "https://i.imgur.com/56aQaCV.png" });

  if ((await launchpad.creationFee()) == 0n) {
    // 5$ in eth
    const efrogsTreasury = "0x4c11F940E2D09eF9D5000668c1C9410f0AaF0833";
    await waitForTx(
      await launchpad.setFeeSettings(
        efrogsTreasury,
        2000000000000000n,
        1000n * e18
      )
    );
  }

  // const token1 = await deployToken(
  //   hre,
  //   deployer,
  //   name,
  //   symbol,
  //   1800, // price of token in USD
  //   tickSpacing,
  //   metadata,
  //   5000, // 5,000$ starting market cap
  //   69000, // 69,000$ ending market cap
  //   wethAddressOnLinea,
  //   launchpad,
  //   tokenImpl,
  //   0n
  // );
  // console.log("Token deployed at", token1.target);

  const shouldMock = false;
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
