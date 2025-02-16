// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Twitter: https://twitter.com/mahaxyz

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAgentToken is IERC20 {
  struct InitParams {
    string name;
    string symbol;
    string metadata;
    uint256 limitPerWallet;
    address[] whitelisted;
  }

  event Unlocked();
  event TransactionVetoed(bytes32 indexed txHash, address indexed by);
  event TransactionScheduled(bytes32 indexed txHash, address indexed to, uint256 value, bytes data, uint256 delay);
  event TransactionExecuted(bytes32 indexed txHash, address caller, address to, uint256 value, bytes data);
  event ExpiryExtended(uint256 expiry);

  function initialize(InitParams memory p) external;
  function unlock() external;
  function unlocked() external view returns (bool);
}
