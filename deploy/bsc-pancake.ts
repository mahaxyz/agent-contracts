import {
  deployAdapter,
  deployToken,
  templateLaunchpad,
} from "./mainnet-template";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { PancakeAdapter } from "../types";
import { deployContract, waitForTx } from "../scripts/utils";
import assert from "assert";

async function main(hre: HardhatRuntimeEnvironment) {
  assert(hre.network.name === "bsc", "This script is only for BSC");

  const deployer = "0x1F09Ec21d7fd0A21879b919bf0f9C46e6b85CA8b";
  const mahaTreasury = "0x7202136d70026DA33628dD3f3eFccb43F62a2469";

  const proxyAdmin = mahaTreasury;
  const wbnbAddressOnBsc = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
  const odosAddressOnBsc = "0x89b8aa89fdd0507a99d334cbe3c808fafc7d850e";
  const nftPositionManager = "0x46A15B0b27311cedF172AB29E4f4766fbE7F4364";
  const mahaAddress = "0x6a661312938d22a2a0e27f585073e4406903990a";
  const cakeAddress = "0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82";
  const locker = "0x25c9C4B56E820e0DEA438b145284F02D9Ca9Bd52";
  const e18 = 10n ** 18n;
  const feeDiscountAmount = 1000n * e18; // 100%

  const { launchpad } = await templateLaunchpad(
    hre,
    deployer,
    proxyAdmin,
    "TokenLaunchpadBSC",
    wbnbAddressOnBsc,
    odosAddressOnBsc,
    mahaAddress,
    feeDiscountAmount
  );

  const adapterPCS = (await deployAdapter(
    hre,
    deployer,
    proxyAdmin,
    "PancakeAdapter",
    launchpad
  )) as PancakeAdapter;

  await deployContract(
    hre,
    "FeeCollector",
    [cakeAddress, mahaAddress, odosAddressOnBsc, wbnbAddressOnBsc],
    "FeeCollector"
  );

  // initialize the PCS contracts if they are not initialized
  if ((await adapterPCS.launchpad()) !== launchpad.target) {
    await waitForTx(
      await adapterPCS.initialize(
        launchpad.target,
        "0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865",
        "0x1b81D678ffb9C0263b24A97847620C99d213eB14",
        wbnbAddressOnBsc,
        locker,
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

  // await waitForTx(await launchpad.setFeeSettings(mahaTreasury, 0, 1000n * e18));

  const shouldMock = false;
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
      adapterPCS,
      deployer,
      name,
      symbol,
      565, // price of token in USD
      tickSpacing,
      1000n,
      metadata,
      5000, // 5,000$ starting market cap
      69000, // 69,000$ ending market cap
      wbnbAddressOnBsc,
      launchpad,
      0n
    );

    console.log("Token deployed at", token2.target);
  }
}

main.tags = ["DeploymentBSC"];
export default main;
