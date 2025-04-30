import {
  deployAdapter,
  deployTokenSimple,
  templateLaunchpad,
} from "./mainnet-template";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { PancakeAdapter, ThenaAdapter } from "../types";
import { deployContract, waitForTx } from "../scripts/utils";
import assert from "assert";
import { ethers } from "hardhat";
import { computeTickPrice } from "./utils";
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
  const thenaAddress = "0xf4c8e32eadec4bfe97e0f595add0f4450a863a11";
  const locker = "0x25c9C4B56E820e0DEA438b145284F02D9Ca9Bd52";
  const e18 = 10n ** 18n;
  const feeDiscountAmount = 1n * e18; // 100%

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
    mahaAddress
  );

  const thenaLockerD = await deployContract(
    hre,
    "ThenaLocker",
    [nftPositionManagerThena],
    "ThenaLocker"
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
    locker: thenaLockerD.address,
    nftPositionManager: nftPositionManagerThena,
    clPoolFactory: clPoolFactoryThena,
  })) as ThenaAdapter;

  const feeCollector = await deployContract(
    hre,
    "FeeCollector",
    [
      cakeAddress,
      mahaAddress,
      odosAddressOnBsc,
      wbnbAddressOnBsc,
      thenaAddress,
    ],
    "FeeCollector"
  );

  // console.log("Getting default launch params for PCS");
  // const defaultLaunchParamsPCS = await launchpad.getDefaultValueParams(
  //   wbnbAddressOnBsc,
  //   adapterPCS.target
  // );
  // console.log("Getting default launch params for Thena");
  // const defaultLaunchParamsThena = await launchpad.getDefaultValueParams(
  //   wbnbAddressOnBsc,
  //   adapterThena.target
  // );

  // calculate ticks
  const launchTick = computeTickPrice(5000, 650, 18, 200);
  const graduationTick = computeTickPrice(69000, 650, 18, 200);

  // if (defaultLaunchParamsPCS.launchTick === 0n) {
  console.log("Setting default launch params for PCS");
  await waitForTx(
    await launchpad.setDefaultValueParams(wbnbAddressOnBsc, adapterPCS.target, {
      launchTick: launchTick,
      graduationTick: graduationTick,
      upperMaxTick: 887_000,
      fee: 10000,
      tickSpacing: 200,
      graduationLiquidity: parseEther("800000000"),
    })
  );
  // }

  // if (defaultLaunchParamsThena.launchTick === 0n) {

  // console.log("Setting default launch params for Thena");
  // await waitForTx(
  //   await launchpad.setDefaultValueParams(
  //     wbnbAddressOnBsc,
  //     adapterThena.target,
  //     {
  //       launchTick: launchTick,
  //       graduationTick: _graduationTick,
  //       upperMaxTick: 887_220,
  //       fee: 3000,
  //       tickSpacing: 60,
  //       graduationLiquidity: parseEther("800000000"),
  //     }
  //   )
  // );
  // // }

  if ((await launchpad.feeDestination()) != feeCollector.address) {
    console.log("Setting fee destination");
    await waitForTx(
      await launchpad.setFeeSettings(feeCollector.address, 0, 1000n * e18)
    );
  }

  // CONTRACTS ARE DEPLOYED; NOW WE CAN LAUNCH A NEW TOKEN

  // setup parameters
  const metadata = JSON.stringify({ image: "https://i.imgur.com/56aQaCV.png" });

  const shouldMockPcs = false;
  const shouldMockThena = false;

  if (shouldMockPcs) {
    const name = "Test PCS Token";
    const symbol = "TEST-PCS";
    const tokenPcs = await deployTokenSimple(
      hre,
      adapterPCS,
      deployer,
      name,
      symbol,
      metadata,
      wbnbAddressOnBsc,
      launchpad,
      0n
    );

    console.log("Pancake Token deployed at", tokenPcs.target);

    const value = 10000000n;

    const buyTx = await swapper.buyWithExactInputWithOdos(
      wbnbAddressOnBsc,
      wbnbAddressOnBsc,
      tokenPcs.target,
      value,
      0,
      0,
      "0x",
      { value }
    );

    console.log("Buy tx", buyTx.hash);

    const token = await ethers.getContractAt("WAGMIEToken", tokenPcs.target);
    await waitForTx(await token.approve(swapper.target, value));
    const sellTx = await swapper.sellWithExactInputWithOdos(
      tokenPcs.target,
      wbnbAddressOnBsc,
      wbnbAddressOnBsc,
      value,
      0,
      0,
      "0x"
    );

    console.log("Sell tx", sellTx.hash);
  }

  if (shouldMockThena) {
    const name = "Test Thena Token";
    const symbol = "TEST-THENA";

    const tokenThena = await deployTokenSimple(
      hre,
      adapterThena,
      deployer,
      name,
      symbol,
      metadata,
      wbnbAddressOnBsc,
      launchpad,
      0n
    );

    console.log("Thena Token deployed at", tokenThena.target);

    const value = 10000000n;

    const buyTx = await swapper.buyWithExactInputWithOdos(
      wbnbAddressOnBsc,
      wbnbAddressOnBsc,
      tokenThena.target,
      value,
      0,
      0,
      "0x",
      { value }
    );

    console.log("Buy tx", buyTx.hash);

    const token = await ethers.getContractAt("WAGMIEToken", tokenThena.target);
    await waitForTx(await token.approve(swapper.target, value));
    const sellTx = await swapper.sellWithExactInputWithOdos(
      tokenThena.target,
      wbnbAddressOnBsc,
      wbnbAddressOnBsc,
      value,
      0,
      0,
      "0x"
    );

    console.log("Sell tx", sellTx.hash);
  }
}

main.tags = ["DeploymentBSC"];
export default main;
