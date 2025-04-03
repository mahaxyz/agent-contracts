// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝    ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {BaseAdapter, IERC20, IWETH9, SafeERC20} from "./BaseAdapter.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {ICLMMAdapter, PoolKey} from "contracts/interfaces/ICLMMAdapter.sol";
import {ITokenTemplate} from "contracts/interfaces/ITokenTemplate.sol";
import {IClPool} from "contracts/interfaces/thirdparty/IClPool.sol";
import {IClPoolFactory} from "contracts/interfaces/thirdparty/IClPoolFactory.sol";
import {IRamsesV2MintCallback} from "contracts/interfaces/thirdparty/pool/IRamsesV2MintCallback.sol";
import {IRamsesSwapRouter} from "contracts/interfaces/thirdparty/ramses/IRamsesSwapRouter.sol";

contract RamsesAdapter is BaseAdapter, IRamsesV2MintCallback {
  using SafeERC20 for IERC20;

  IClPoolFactory public clPoolFactory;
  IRamsesSwapRouter public swapRouter;
  IClPool private _transientClPool;

  function initialize(address _launchpad, address _clPoolFactory, address _swapRouter, address _WETH9)
    external
    initializer
  {
    __BaseAdapter_init(_launchpad, _WETH9);
    clPoolFactory = IClPoolFactory(_clPoolFactory);
    swapRouter = IRamsesSwapRouter(_swapRouter);
  }

  /// @inheritdoc ICLMMAdapter
  function addSingleSidedLiquidity(IERC20 _tokenBase, IERC20 _tokenQuote, int24 _tick0, int24 _tick1, int24 _tick2)
    external
  {
    require(msg.sender == launchpad, "!launchpad");
    require(launchParams[_tokenBase].pool == address(0), "!launched");

    uint160 sqrtPriceX96Launch = TickMath.getSqrtPriceAtTick(_tick0 - 1);
    uint160 sqrtPriceX960 = TickMath.getSqrtPriceAtTick(_tick0);
    uint160 sqrtPriceX961 = TickMath.getSqrtPriceAtTick(_tick1);
    uint160 sqrtPriceX962 = TickMath.getSqrtPriceAtTick(_tick2);

    IClPool pool =
      IClPool(clPoolFactory.createPool(address(_tokenBase), address(_tokenQuote), 20_000, sqrtPriceX96Launch));

    {
      PoolKey memory poolKey = PoolKey({
        currency0: Currency.wrap(address(_tokenBase)),
        currency1: Currency.wrap(address(_tokenQuote)),
        fee: 20_000,
        tickSpacing: 500,
        hooks: IHooks(address(0))
      });
      launchParams[_tokenBase] =
        LaunchTokenParams({pool: address(pool), poolKey: poolKey, tick0: _tick0, tick1: _tick1, tick2: _tick2});
      require(address(_tokenBase) == pool.token0(), "!token0");
      ITokenTemplate(address(_tokenBase)).whitelist(address(pool));
    }

    // calculate the liquidity for the various tick ranges
    uint128 liquidityBeforeTick0 =
      LiquidityAmounts.getLiquidityForAmount0(sqrtPriceX960, sqrtPriceX961, 600_000_000 ether);
    uint128 liquidityBeforeTick1 =
      LiquidityAmounts.getLiquidityForAmount0(sqrtPriceX961, sqrtPriceX962, 400_000_000 ether);

    // add liquidity to the various tick ranges
    _transientClPool = pool;
    pool.mint(_me, _tick0, _tick1, liquidityBeforeTick0, "");
    pool.mint(_me, _tick1, _tick2, liquidityBeforeTick1, "");
    delete _transientClPool;
  }

  /// @inheritdoc ICLMMAdapter
  function swapWithExactOutput(IERC20 _tokenIn, IERC20 _tokenOut, uint256 _amountOut, uint256 _maxAmountIn)
    external
    returns (uint256 amountIn)
  {
    _tokenIn.safeTransferFrom(msg.sender, address(this), _maxAmountIn);
    _tokenIn.approve(address(swapRouter), type(uint256).max);
    amountIn = swapRouter.exactOutputSingle(
      IRamsesSwapRouter.ExactOutputSingleParams({
        tokenIn: address(_tokenIn),
        tokenOut: address(_tokenOut),
        amountOut: _amountOut,
        recipient: msg.sender,
        deadline: block.timestamp,
        fee: 20_000,
        amountInMaximum: _maxAmountIn,
        sqrtPriceLimitX96: 0
      })
    );
    _refundTokens(_tokenIn);
  }

  /// @inheritdoc ICLMMAdapter
  function swapWithExactInput(IERC20 _tokenIn, IERC20 _tokenOut, uint256 _amountIn, uint256 _minAmountOut)
    external
    returns (uint256 amountOut)
  {
    _tokenIn.safeTransferFrom(msg.sender, address(this), _amountIn);
    _tokenIn.approve(address(swapRouter), type(uint256).max);

    amountOut = swapRouter.exactInputSingle(
      IRamsesSwapRouter.ExactInputSingleParams({
        tokenIn: address(_tokenIn),
        tokenOut: address(_tokenOut),
        amountIn: _amountIn,
        recipient: msg.sender,
        deadline: block.timestamp,
        fee: 20_000,
        amountOutMinimum: _minAmountOut,
        sqrtPriceLimitX96: 0
      })
    );
  }

  /// @inheritdoc ICLMMAdapter
  function claimFees(address _token) external returns (uint256 fee0, uint256 fee1) {
    LaunchTokenParams memory params = launchParams[IERC20(_token)];
    require(params.pool != address(0), "!launched");

    (uint256 fee00, uint256 fee01) =
      IClPool(params.pool).collect(_me, params.tick0, params.tick1, type(uint128).max, type(uint128).max);
    (uint256 fee10, uint256 fee11) =
      IClPool(params.pool).collect(_me, params.tick1, params.tick2, type(uint128).max, type(uint128).max);

    fee0 = fee00 + fee10;
    fee1 = fee01 + fee11;

    IERC20(IClPool(params.pool).token0()).transfer(msg.sender, fee0);
    IERC20(IClPool(params.pool).token1()).transfer(msg.sender, fee1);
  }

  /// @inheritdoc ICLMMAdapter
  function graduated(address token) external view returns (bool) {
    LaunchTokenParams memory params = launchParams[IERC20(token)];
    if (params.pool == address(0)) return false;
    (, int24 tick,,,,,) = IClPool(params.pool).slot0();
    return tick >= params.tick1;
  }

  function ramsesV2MintCallback(uint256 amount0, uint256, bytes calldata) external {
    require(msg.sender == address(_transientClPool) && address(_transientClPool) != address(0), "!clPool");
    IERC20(_transientClPool.token0()).transferFrom(launchpad, msg.sender, amount0);
  }
}
