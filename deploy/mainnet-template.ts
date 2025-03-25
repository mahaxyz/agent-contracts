import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, deployProxy, waitForTx } from "../scripts/utils";

export async function templateLaunchpad(
  hre: HardhatRuntimeEnvironment,
  deployer: string,
  proxyAdmin: string,
  adapterContract: string,
  launchpadContract: string,
  wethAddress: string
) {
  const tokenD = await deployContract(
    hre,
    "WAGMIEToken",
    [],
    "TokenTemplateImpl"
  );

  const adapterD = await deployProxy(
    hre,
    adapterContract,
    [],
    proxyAdmin,
    adapterContract,
    deployer,
    true // skip initialization
  );

  const launchpadD = await deployProxy(
    hre,
    launchpadContract,
    [adapterD.address, tokenD.address, deployer, wethAddress],
    proxyAdmin,
    launchpadContract,
    deployer
  );

  const launchpad = await hre.ethers.getContractAt(
    "TokenLaunchpad",
    launchpadD.address
  );
  const tokenImpl = await hre.ethers.getContractAt(
    "WAGMIEToken",
    tokenD.address
  );
  const adapter = await hre.ethers.getContractAt(
    "ICLMMAdapter",
    adapterD.address
  );

  // initialize the contracts if they are not initialized
  if ((await tokenImpl.name()) !== "TEST") {
    await waitForTx(
      await tokenImpl.initialize({
        name: "TEST", // string name;
        symbol: "TEST", // string symbol;
        metadata: "TEST", // string metadata;
        limitPerWallet: 1000000000000000000n, // uint256 limitPerWallet;
        adapter: adapterD.address, // address adapter;
      })
    );
  }

  return {
    adapter,
    launchpad,
    tokenImpl,
  };
}
