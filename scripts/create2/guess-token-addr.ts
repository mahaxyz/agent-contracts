import { AbiCoder, Addressable, ethers, keccak256 } from "ethers";
import { getPredictedCloneAddress } from "./create2";

export const guessTokenAddress = (
  deployingAddress: string | Addressable,
  implementationAddress: string | Addressable,
  quoteTokenAddress: string | Addressable,
  deployerAddress: string,
  name: string,
  symbol: string
) => {
  let i = 0;

  const abi = new AbiCoder();

  while (true) {
    const salt = ethers.id("" + i + Date.now());
    const saltHash = keccak256(
      abi.encode(
        ["bytes32", "address", "string", "string"],
        [salt, deployerAddress, name, symbol]
      )
    );

    // Calculate contract address
    const computedAddress = getPredictedCloneAddress({
      salt: saltHash,
      implementation: implementationAddress as string,
      deployer: deployingAddress as string,
    });

    if (computedAddress < quoteTokenAddress) {
      console.log("found the right salt hash");
      console.log("salt", salt, computedAddress);
      return { salt, computedAddress };
    }

    if (i % 100000 == 0) console.log(i, "salt", salt, computedAddress);
    i++;
  }
};
