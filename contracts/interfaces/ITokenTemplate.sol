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

/// @title ITokenTemplate Interface
/// @notice Interface for the TokenTemplate contract that implements a token with presale functionality
interface ITokenTemplate is IERC20 {
  /// @notice Parameters for initializing a new token
  /// @param name The name of the token
  /// @param symbol The symbol of the token
  /// @param metadata Additional metadata about the token
  /// @param limitPerWallet Maximum tokens per wallet during presale
  /// @param adapter Address of the CLMM adapter contract
  struct InitParams {
    string name;
    string symbol;
    string metadata;
    uint256 limitPerWallet;
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

  /// @notice Returns whether the token is unlocked for unrestricted transfers
  /// @return bool True if unlocked, false otherwise
  function unlocked() external view returns (bool);

  /// @notice Checks if an address is whitelisted
  /// @param _address The address to check
  /// @return bool True if whitelisted, false otherwise
  function isWhitelisted(address _address) external view returns (bool);

  /// @notice Adds an address to the whitelist
  /// @param _address The address to whitelist
  function whitelist(address _address) external;
}
