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

  await waitForTx(await launchpad.whitelist(mahaD.address, true));

  // mint some tokens
  await waitForTx(await maha.mint(deployer.address, 100000000000n * e18));

  const data = {
    base: {
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: "0xe5d7c2a44ffddf6b295a15c148167daaaf5cf34f",
      fee: 3000,
      limitPerWallet: 1000,
      salt: keccak256("0x12"),
    },
    liquidity: {
      amountBaseBeforeTick: 600_000_000n * e18,
      amountBaseAfterTick: 400_000_000n * e18,
      lowerTick: 46020, // Price of 1 ETH per token
      upperTick: 46080, // Price of 2 ETH per token
      upperMaxTick: 887220, // Maximum possible tick value
    },
  };

  // create a launchpad token
  console.log("creating a launchpad token");
  console.log("data", await launchpad.create.populateTransaction(data));
  await waitForTx(await launchpad.create(data));

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
