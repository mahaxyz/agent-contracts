import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, deployProxy, waitForTx } from "../scripts/utils";
import { keccak256, MaxUint256, ZeroAddress } from "ethers";

async function main(hre: HardhatRuntimeEnvironment) {
  const [deployer] = await hre.ethers.getSigners();

  const e18 = 1000000000000000000n;

  const mahaD = await deployContract(
    hre,
    "MockERC20",
    ["TEST MAHA", "TMAHA", 18],
    "MAHA"
  );

  const tokenD = await deployContract(hre, "AgentToken", [], "AgentTokenImpl");
  const launchpadD = await deployContract(
    hre,
    "AgentLaunchpad",
    [],
    "AgentLaunchpad"
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

  await waitForTx(
    await tokenImpl.initialize({
      name: "", // string name;
      symbol: "", // string symbol;
      metadata: "", // string metadata;
      whitelisted: [deployer.address], // address[] fundManagers;
      limitPerWallet: 0, // uint256 limitPerWallet;
    })
  );
  await waitForTx(
    await launchpad.initialize(
      mahaD.address,
      "0x19ceead7105607cd444f5ad10dd51356436095a1",
      "0x420DD381b31aEf6683db6B902084cB0FFECe40Da",
      tokenD.address,
      deployer.address
    )
  );

  await waitForTx(
    await launchpad.setSettings(
      0, // uint256 _creationFee,
      86400 * 365, // uint256 _maxDuration,
      0, // uint256 _minDuration,
      0, // uint256 _minFundingGoal,
      deployer.address, // address _feeDestination,
      (5n * e18) / 10n // uint256 _feeCutE18
    )
  );

  await waitForTx(await launchpad.whitelist(mahaD.address, true));

  // mint some tokens
  await waitForTx(await maha.mint(deployer.address, 100000000000n * e18));

  // create a launchpad token
  console.log("creating a launchpad token");
  await waitForTx(
    await launchpad.create({
      name: "test", // string name;
      symbol: "test", // string symbol;
      limitPerWallet: 10000000000n * e18, // uint256 limitPerWallet;
      goal: 10000n * e18, // uint256 goal; - 10,000 MAHA
      tokensToSell: 10000000000n * e18, // uint256 tokensToSell;
      metadata: "{}", // string metadata;
      bondingCurve: curve.address, // address bondingCurve;
      fundingToken: maha.target, // address fundingToken;
      salt: keccak256("0x"), // bytes32 salt;
    })
  );

  const lastToken = await hre.ethers.getContractAt(
    "AgentToken",
    await launchpad.tokens((await launchpad.getTotalTokens()) - 1n)
  );

  // perform a swap
  console.log("performing a swap");
  await waitForTx(await maha.approve(launchpad.target, MaxUint256));
  await waitForTx(await lastToken.approve(launchpad.target, MaxUint256));
  await waitForTx(
    await launchpad.presaleSwap(
      lastToken.target,
      deployer.address,
      100000000n * e18,
      "0",
      true
    )
  );
  await waitForTx(
    await launchpad.presaleSwap(
      lastToken.target,
      deployer.address,
      10000000n * e18,
      "0",
      false
    )
  );
  await waitForTx(
    await launchpad.presaleSwap(
      lastToken.target,
      deployer.address,
      10000000000n * e18,
      "0",
      true
    )
  );
}

main.tags = ["TestDeployment"];
export default main;
