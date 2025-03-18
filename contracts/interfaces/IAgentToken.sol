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
    address adapter;
  }

  event Unlocked();
  event Whitelisted(address indexed _address);

  function initialize(InitParams memory p) external;

  function unlocked() external view returns (bool);

  function isWhitelisted(address _address) external view returns (bool);

  function whitelist(address _address) external;
}
