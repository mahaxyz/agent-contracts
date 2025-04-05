// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Telegram: https://t.me/mahaxyz
// Twitter: https://twitter.com/mahaxyz

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ITokenTemplate Interface
/// @notice Interface for the WAGMIEToken contract that implements a token with presale functionality
interface ITokenTemplate is IERC20 {
  /// @notice Parameters for initializing a new token
  /// @param name The name of the token
  /// @param symbol The symbol of the token
  /// @param metadata Additional metadata about the token
  /// @param adapter Address of the CLMM adapter contract
  struct InitParams {
    string name;
    string symbol;
    string metadata;
    address adapter;
  }

  /// @notice Emitted when the token is unlocked for unrestricted transfers
  event Unlocked();

  /// @notice Emitted when an address is whitelisted
  /// @param _address The whitelisted address
  event Whitelisted(address indexed _address);

  /// @notice Initializes the token with the given parameters
  /// @param p The initialization parameters
  function initialize(InitParams memory p) external;
}
