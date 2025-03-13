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

/// @title Concentrated Liquidity Market Maker Adapter Interface
/// @notice Interface for interacting with concentrated liquidity pools
/// @dev Implements single-sided liquidity provision and fee claiming
interface ICLMMAdapter {
  /// @notice Add single-sided liquidity to a concentrated pool
  /// @dev Provides liquidity across three ticks with different amounts
  /// @param _token The token address to provide liquidity for
  /// @param _amountBeforeTick Amount to provide before the first tick
  /// @param _amountAfterTick Amount to provide after the last tick
  /// @param _tick0 The first tick position
  /// @param _tick1 The second tick position
  /// @param _tick2 The third tick position
  function addSingleSidedLiquidity(
    address _token,
    uint256 _amountBeforeTick,
    uint256 _amountAfterTick,
    int128 _tick0,
    int128 _tick1,
    int128 _tick2
  ) external;

  /// @notice Claim accumulated fees from the pool
  /// @param _token The token address to claim fees for
  function claimFees(address _token) external;
}
