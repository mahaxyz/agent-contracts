import { keccak256 } from "ethers";

const buildCreate2Address = (
  factoryAddress: string,
  saltHex: string,
  byteCode: string
) => {
  return `0x${keccak256(
    `0x${["ff", factoryAddress, saltHex, keccak256(byteCode)]
      .map((x) => x.replace(/0x/, ""))
      .join("")}`
  ).slice(-40)}`.toLowerCase();
};

// Predicts the address for an EIP-1167 minimal proxy clone using cloneDeterministic
export function getPredictedCloneAddress({
  implementation,
  salt,
  deployer,
}: {
  implementation: string;
  salt: string;
  deployer: string;
}) {
  // This is the EIP-1167 minimal proxy bytecode with implementation address
  const minimalProxyBytecode = `0x3d602d80600a3d3981f3363d3d373d3d3d363d73${implementation
    .slice(2)
    .toLowerCase()}5af43d82803e903d91602b57fd5bf3`;

  return buildCreate2Address(deployer, salt, minimalProxyBytecode);
}
