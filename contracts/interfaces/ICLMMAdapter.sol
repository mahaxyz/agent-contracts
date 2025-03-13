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
  /// @param _tokenBase The base token address
  /// @param _tokenQuote The quote token address
  /// @param _amountBaseBeforeTick The amount of base token to provide before the middle tick
  /// @param _amountBaseAfterTick The amount of base token to provide after the middle tick
  /// @param _tick0 The first tick position
  /// @param _tick1 The second tick position
  /// @param _tick2 The third tick position
  function addSingleSidedLiquidity(
    address _tokenBase,
    address _tokenQuote,
    uint256 _amountBaseBeforeTick,
    uint256 _amountBaseAfterTick,
    int128 _tick0,
    int128 _tick1,
    int128 _tick2
  ) external;

  /// @notice Rebalances the liquidity after graduation
  /// @param _tokenBase The base token address
  function rebalanceLiquidityAfterGraduation(address _tokenBase) external;

  /// @notice Claim accumulated fees from the pool
  /// @param _pool The pool address to claim fees for
  /// @return fee0 The amount of fee0
  /// @return fee1 The amount of fee1
  function claimFees(address _pool) external returns (uint256 fee0, uint256 fee1);
}
