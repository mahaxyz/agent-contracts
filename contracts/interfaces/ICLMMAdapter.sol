// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://wagmie.com
// Telegram: https://t.me/mahaxyz
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IClPool} from "contracts/interfaces/thirdparty/IClPool.sol";

/// @title Concentrated Liquidity Market Maker Adapter Interface
/// @notice Interface for interacting with concentrated liquidity pools
/// @dev Implements single-sided liquidity provision and fee claiming
interface ICLMMAdapter {
  struct LaunchTokenParams {
    IERC20 tokenBase;
    IERC20 tokenQuote;
    address pool;
    PoolKey poolKey;
    int24 tick0;
    int24 tick1;
    int24 tick2;
  }

  /// @notice Parameters for adding liquidity to a pool
  struct AddLiquidityParams {
    IERC20 tokenBase;
    IERC20 tokenQuote;
    int24 tick0;
    int24 tick1;
    int24 tick2;
    uint24 fee;
    int24 tickSpacing;
    uint256 totalAmount;
    uint256 graduationAmount;
  }

  /// @notice Returns the address of the pool for a given token
  /// @param _token The token address
  /// @return pool The address of the pool
  function getPool(IERC20 _token) external view returns (address pool);

  /// @notice Add single-sided liquidity to a concentrated pool
  /// @dev Provides liquidity across three ticks with different amounts
  function addSingleSidedLiquidity(AddLiquidityParams memory _params) external;

  /// @notice Swap a token with exact output
  /// @param _tokenIn The token to swap
  /// @param _tokenOut The token to receive
  /// @param _amountOut The amount of tokens to swap
  /// @param _maxAmountIn The maximum amount of tokens to receive
  /// @return amountIn The amount of tokens received
  function swapWithExactOutput(IERC20 _tokenIn, IERC20 _tokenOut, uint256 _amountOut, uint256 _maxAmountIn, uint24 _fee)
    external
    returns (uint256 amountIn);

  /// @notice Swap a token with exact input
  /// @param _tokenIn The token to swap
  /// @param _tokenOut The token to receive
  /// @param _amountIn The amount of tokens to swap
  /// @param _minAmountOut The minimum amount of tokens to receive
  /// @return amountOut The amount of tokens received
  function swapWithExactInput(IERC20 _tokenIn, IERC20 _tokenOut, uint256 _amountIn, uint256 _minAmountOut, uint24 _fee)
    external
    returns (uint256 amountOut);

  /// @notice Returns the address of the Launchpad contract
  /// @return launchpad The address of the Launchpad contract
  function launchpad() external view returns (address launchpad);

  /// @notice Checks if a token has been launched
  /// @param _token The token address to check
  /// @return launched true if the token has been launched, false otherwise
  function launchedTokens(IERC20 _token) external view returns (bool launched);

  /// @notice Claim accumulated fees from the pool
  /// @param _token The token address to claim fees for
  /// @return fee0 The amount of token0 fees to claim
  /// @return fee1 The amount of token1 fees to claim
  function claimFees(address _token) external returns (uint256 fee0, uint256 fee1);
}
