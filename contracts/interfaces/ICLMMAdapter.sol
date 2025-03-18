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
  /// @notice Add single-sided liquidity to a concentrated pool
  /// @dev Provides liquidity across three ticks with different amounts
  function addSingleSidedLiquidity(
    IERC20 _tokenBase,
    IERC20 _tokenQuote,
    uint256 _amountBaseBeforeTick,
    uint256 _amountBaseAfterTick,
    uint24 _fee,
    int24 _tick0,
    int24 _tick1,
    int24 _tick2
  ) external;

  function LAUNCHPAD() external view returns (address);

  function launchedTokens(IERC20 _token) external view returns (bool launched);

  /// @notice Claim accumulated fees from the pool
  function claimFees(address _token) external returns (uint256 fee0, uint256 fee1);

  /// @notice Check if a token has graduated
  /// @param _token The token address to check
  /// @return true if the token has graduated, false otherwise
  function graduated(address _token) external view returns (bool);
}
