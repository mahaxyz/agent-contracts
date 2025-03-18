import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, deployProxy, waitForTx } from "../scripts/utils";
import { keccak256, MaxUint256, ZeroAddress } from "ethers";

async function main(hre: HardhatRuntimeEnvironment) {
  const [deployer] = await hre.ethers.getSigners();

  console.log("deployer", deployer.address);
  const e18 = 1000000000000000000n;

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

  const adapter = await deployContract(
    hre,
    "RamsesAdapter",
    [
      launchpad.target, // address _launchpad,
      "0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42", // address _clPoolFactory
    ],
    "RamsesAdapter"
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
      adapter.address,
      tokenD.address,
      deployer.address
    )
  );

  await waitForTx(await launchpad.whitelist(mahaD.address, true));

  // mint some tokens
  await waitForTx(await maha.mint(deployer.address, 100000000000n * e18));

  // create a launchpad token
  console.log("creating a launchpad token");
  await waitForTx(
    await launchpad.create({
      base: {
        name: "Test Token",
        symbol: "TEST",
        metadata: "Test metadata",
        fundingToken: mahaD.address,
        fee: 3000,
        limitPerWallet: 1000,
        salt: keccak256("0x"),
      },
      liquidity: {
        amountBaseBeforeTick: 600_000_000n * e18,
        amountBaseAfterTick: 400_000_000n * e18,
        initialSqrtPrice: 79_228_162_514_264_337_593_543_950_336n, // sqrt(1) * 2^96 for 1 ETH per token
        lowerTick: 6931, // Price of 1 ETH per token
        upperTick: 6932, // Price of 2 ETH per token
        upperMaxTick: 46_052, // Price of 100 ETH per token
      },
    })
  );

  const lastToken = await hre.ethers.getContractAt(
    "AgentToken",
    await launchpad.tokens((await launchpad.getTotalTokens()) - 1n)
  );

  // // perform a swap
  // console.log("performing a swap");
  // await waitForTx(await maha.approve(launchpad.target, MaxUint256));
  // await waitForTx(await lastToken.approve(launchpad.target, MaxUint256));
  // await waitForTx(
  //   await launchpad.presaleSwap(
  //     lastToken.target,
  //     deployer.address,
  //     100000000n * e18,
  //     "0",
  //     true
  //   )
  // );
  // await waitForTx(
  //   await launchpad.presaleSwap(
  //     lastToken.target,
  //     deployer.address,
  //     10000000n * e18,
  //     "0",
  //     false
  //   )
  // );
  // await waitForTx(
  //   await launchpad.presaleSwap(
  //     lastToken.target,
  //     deployer.address,
  //     10000000000n * e18,
  //     "0",
  //     true
  //   )
  // );
}

main.tags = ["TestDeploymentNile"];
export default main;
