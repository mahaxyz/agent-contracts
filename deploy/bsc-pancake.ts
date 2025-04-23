import {
  deployAdapter,
  deployToken,
  templateLaunchpad,
} from "./mainnet-template";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { PancakeAdapter, ThenaAdapter } from "../types";
import { deployContract, waitForTx } from "../scripts/utils";
import assert from "assert";
import { parseEther } from "ethers";

async function main(hre: HardhatRuntimeEnvironment) {
  assert(hre.network.name === "bsc", "This script is only for BSC");

  const deployer = "0x1F09Ec21d7fd0A21879b919bf0f9C46e6b85CA8b";
  const mahaTreasury = "0x7202136d70026DA33628dD3f3eFccb43F62a2469";

  const proxyAdmin = mahaTreasury;
  const wbnbAddressOnBsc = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
  const odosAddressOnBsc = "0x89b8aa89fdd0507a99d334cbe3c808fafc7d850e";
  const mahaAddress = "0x6a661312938d22a2a0e27f585073e4406903990a";
  const cakeAddress = "0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82";
  const locker = "0x25c9C4B56E820e0DEA438b145284F02D9Ca9Bd52";
  const e18 = 10n ** 18n;
  const feeDiscountAmount = 1000n * e18; // 100%

  const nftPositionManagerPCS = "0x46A15B0b27311cedF172AB29E4f4766fbE7F4364";
  const nftPositionManagerThena = "0xa51ADb08Cbe6Ae398046A23bec013979816B77Ab";
  const clPoolFactoryPCS = "0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865";
  const clPoolFactoryThena = "0x306F06C147f064A010530292A1EB6737c3e378e4";
  const swapRouterPCS = "0x1b81D678ffb9C0263b24A97847620C99d213eB14";
  const swapRouterThena = "0x327Dd3208f0bCF590A66110aCB6e5e6941A4EfA0";

  const { launchpad, swapper } = await templateLaunchpad(
    hre,
    deployer,
    proxyAdmin,
    "TokenLaunchpadBSC",
    wbnbAddressOnBsc,
    odosAddressOnBsc,
    mahaAddress,
    feeDiscountAmount
  );

  const adapterPCS = (await deployAdapter(hre, "PancakeAdapter", {
    launchpad,
    wethAddress: wbnbAddressOnBsc,
    swapRouter: swapRouterPCS,
    locker,
    nftPositionManager: nftPositionManagerPCS,
    clPoolFactory: clPoolFactoryPCS,
  })) as PancakeAdapter;

  const adapterThena = (await deployAdapter(hre, "ThenaAdapter", {
    launchpad,
    wethAddress: wbnbAddressOnBsc,
    swapRouter: swapRouterThena,
    locker,
    nftPositionManager: nftPositionManagerThena,
    clPoolFactory: clPoolFactoryThena,
  })) as ThenaAdapter;

  const feeCollector = await deployContract(
    hre,
    "FeeCollector",
    [cakeAddress, mahaAddress, odosAddressOnBsc, wbnbAddressOnBsc],
    "FeeCollector"
  );

  if ((await launchpad.getValueParams(wbnbAddressOnBsc)).fee !== 10000n) {
    await waitForTx(
      await launchpad.setValueParams(wbnbAddressOnBsc, {
        launchTick: -171_000,
        graduationTick: -170_800,
        upperMaxTick: 887_000,
        fee: 10000,
        tickSpacing: 200,
        graduationLiquidity: parseEther("800000000"),
      })
    );
  }

  console.log("Value params", await launchpad.getValueParams(wbnbAddressOnBsc));

  if ((await launchpad.feeDestination()) != feeCollector.address) {
    await waitForTx(
      await launchpad.setFeeSettings(feeCollector.address, 0, 1000n * e18)
    );
  }

  // CONTRACTS ARE DEPLOYED; NOW WE CAN LAUNCH A NEW TOKEN

  // setup parameters
  const name = "Test Token";
  const symbol = "TEST";
  const tickSpacing = 200; // tick spacing for 1% fee
  const metadata = JSON.stringify({ image: "https://i.imgur.com/56aQaCV.png" });

  // await waitForTx(await launchpad.setFeeSettings(mahaTreasury, 0, 1000n * e18));

  const shouldMock = true;
  if (shouldMock) {
    // const mahaD = await deployContract(
    //   hre,
    //   "MockERC20",
    //   ["TEST MAHA", "TMAHA", 18],
    //   "MAHA"
    // );

    // const maha = await hre.ethers.getContractAt("MockERC20", mahaD.address);

    // await waitForTx(await maha.mint(deployer, 1000000000000000000000000n));
    // await waitForTx(
    //   await maha.approve(launchpad.target, 1000000000000000000000000n)
    // );

    const token2 = await deployToken(
      hre,
      adapterThena,
      deployer,
      name,
      symbol,
      565, // price of token in USD
      tickSpacing,
      10000n,
      metadata,
      5000, // 5,000$ starting market cap
      69000, // 69,000$ ending market cap
      wbnbAddressOnBsc,
      launchpad,
      0n
    );

    console.log("Token deployed at", token2.target);

    const value = 10000000n;

    const swapTx = await swapper.buyWithExactInputWithOdos(
      wbnbAddressOnBsc,
      wbnbAddressOnBsc,
      "0x9215380C8Bf8f56CeBd43508B72b77a4cA42afC4",
      value,
      0,
      0,
      "0x",
      { value }
    );

    console.log("Swap tx", swapTx);
  }
}

main.tags = ["DeploymentBSC"];
export default main;
