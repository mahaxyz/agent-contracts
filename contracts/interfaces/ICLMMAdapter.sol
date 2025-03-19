// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Concentrated Liquidity Market Maker Adapter Interface
/// @notice Interface for interacting with concentrated liquidity pools
/// @dev Implements single-sided liquidity provision and fee claiming
interface ICLMMAdapter {
  /// @notice Returns the address of the pool for a given token
  /// @param _token The token address
  /// @return pool The address of the pool
  function getPool(IERC20 _token) external view returns (address pool);

  /// @notice Add single-sided liquidity to a concentrated pool
  /// @dev Provides liquidity across three ticks with different amounts
  function addSingleSidedLiquidity(
    IERC20 _tokenBase,
    IERC20 _tokenQuote,
    uint24 _fee,
    int24 _tick0,
    int24 _tick1,
    int24 _tick2
  ) external;

  /// @notice Returns the address of the Launchpad contract
  /// @return The address of the Launchpad contract
  function launchpad() external view returns (address);

  /// @notice Checks if a token has been launched
  /// @param _token The token address to check
  /// @return launched true if the token has been launched, false otherwise
  function launchedTokens(IERC20 _token) external view returns (bool launched);

  /// @notice Claim accumulated fees from the pool
  /// @param _token The token address to claim fees for
  /// @return fee0 The amount of token0 fees to claim
  /// @return fee1 The amount of token1 fees to claim
  function claimFees(address _token) external returns (uint256 fee0, uint256 fee1);

  /// @notice Check if a token has graduated
  /// @param _token The token address to check
  /// @return true if the token has graduated, false otherwise
  function graduated(address _token) external view returns (bool);
}
