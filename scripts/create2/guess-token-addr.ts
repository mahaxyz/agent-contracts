import { AbiCoder, Addressable, ethers, keccak256 } from "ethers";

export const guessTokenAddress = (
  deployingAddress: string | Addressable,
  implementationByteCode: string,
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

    // Get the creation bytecode for WAGMIEToken

    // Encode constructor parameters
    const encodedParams = abi.encode(["string", "string"], [name, symbol]);

    // Combine bytecode and encoded constructor params
    const initCode = implementationByteCode + encodedParams.slice(2);

    // Calculate CREATE2 address
    const computedAddress = ethers.getCreate2Address(
      deployingAddress as string,
      saltHash,
      keccak256(initCode)
    );

    if (computedAddress < quoteTokenAddress) {
      console.log("found the right salt hash");
      console.log("salt", salt, computedAddress);
      return { salt, computedAddress };
    }

    if (i % 100000 == 0) console.log(i, "salt", salt, computedAddress);
    i++;
  }
};
