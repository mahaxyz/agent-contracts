import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, deployProxy, waitForTx } from "../scripts/utils";
import assert from "assert";
import { ZeroAddress } from "ethers";

async function main(hre: HardhatRuntimeEnvironment) {
  const [deployer] = await hre.ethers.getSigners();

  const locker = await deployContract(hre, "Locker", [], "Locker");
  const checker = await deployContract(hre, "TxChecker", [], "TxChecker");
  const curve = await deployContract(hre, "FixedCurve", [], "FixedCurve");
  const maha = await deployContract(
    hre,
    "MockERC20",
    ["MAHA", "MAHA", 18],
    "MAHA"
  );

  const launchpadD = await deployProxy(
    hre,
    "AgentLaunchpad",
    [maha.address, "0x7202136d70026DA33628dD3f3eFccb43F62a2469"],
    deployer.address,
    "AgentLaunchpad"
  );
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
}

main.tags = ["TestDeployment"];
export default main;
