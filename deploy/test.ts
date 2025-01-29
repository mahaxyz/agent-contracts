import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, deployProxy, waitForTx } from "../scripts/utils";
import { keccak256, ZeroAddress } from "ethers";

async function main(hre: HardhatRuntimeEnvironment) {
  const [deployer] = await hre.ethers.getSigners();

  const locker = await deployContract(hre, "Locker", [], "Locker");
  const checker = await deployContract(hre, "TxChecker", [], "TxChecker");
  const curve = await deployContract(hre, "FixedCurve", [], "FixedCurve");
  const mahaD = await deployContract(
    hre,
    "MockERC20",
    ["TEST MAHA", "TMAHA", 18],
    "MAHA"
  );

  const launchpadD = await deployProxy(
    hre,
    "AgentLaunchpad",
    [mahaD.address, deployer.address],
    "0x7202136d70026DA33628dD3f3eFccb43F62a2469",
    "AgentLaunchpad"
  );

  const maha = await hre.ethers.getContractAt("MockERC20", mahaD.address);
  const launchpad = await hre.ethers.getContractAt(
    "AgentLaunchpad",
    launchpadD.address
  );

  console.log("Locker deployed to:", locker.address);

  await waitForTx(
    await launchpad.setSettings(
      0, // uint256 _creationFee,
      0, // uint256 _minFundingGoal,
      0, // uint256 _minDuration,
      86400 * 10, // uint256 _maxDuration,
      locker.address, // address _locker,
      checker.address, // address _checker,
      ZeroAddress // address _governor
    )
  );

  await waitForTx(await launchpad.whitelist(curve.address, true));

  // mint some tokens
  await waitForTx(
    await maha.mint(deployer.address, "100000000000000000000000000000")
  );

  // create a launchpad token
  console.log("creating a launchpad token");
  await waitForTx(
    await launchpad.create({
      name: "test", // string name;
      symbol: "test", // string symbol;
      duration: 86400 * 2, // uint256 duration;
      limitPerWallet: "100000000000000000000000000", // uint256 limitPerWallet;
      goal: "1000000000000000000000000000", // uint256 goal;
      metadata: "{}", // string metadata;
      locker: locker.address, // address locker;
      txChecker: checker.address, // address txChecker;
      bondingCurve: curve.address, // address bondingCurve;
      salt: keccak256("0x"), // bytes32 salt;
    })
  );

  const lastToken = await hre.ethers.getContractAt(
    "AgentToken",
    await launchpad.tokens((await launchpad.getTotalTokens()) - 1n)
  );

  // perform a swap
  console.log("performing a swap");
  await waitForTx(await maha.approve(lastToken.target, "10000"));
  await waitForTx(await lastToken.presaleSwap("10000", "10000", true));
  await waitForTx(await lastToken.presaleSwap("1000", "1000", false));
}

main.tags = ["TestDeployment"];
export default main;
