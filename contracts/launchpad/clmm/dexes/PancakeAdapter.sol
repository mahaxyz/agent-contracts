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

import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IClPool} from "contracts/interfaces/thirdparty/IClPool.sol";
import {IClPoolFactory} from "contracts/interfaces/thirdparty/IClPoolFactory.sol";
import {IPancakeSwapRouter} from "contracts/interfaces/thirdparty/pancake/IPancakeSwapRouter.sol";

contract PancakeAdapter is ICLMMAdapter {
  using SafeERC20 for IERC20;

  IClPoolFactory public clPoolFactory;
  address public launchpad;
  mapping(IERC20 token => LaunchTokenParams params) public launchParams;
  address private _me;
  address public WETH9;
  IClPool private _transientClPool;
  IPancakeSwapRouter public swapRouter;

  function initialize(address _launchpad, address _clPoolFactory, address _swapRouter, address _WETH9) 
    external 
    initializer
  {
    launchpad = _launchpad;
    clPoolFactory = IClPoolFactory(_clPoolFactory);
    swapRouter = IPancakeSwapRouter(_swapRouter);
    _me = address(this);
    WETH9 = _WETH9;
  }

  function launchedTokens(IERC20 _token) external view returns (bool launched) {
    launched = launchParams[_token].pool != IClPool(address(0));
  }

  function getPool(IERC20 _token) external view returns (address pool) {
    return address(launchParams[_token].pool);
  }

  function addSingleSidedLiquidity(
    IERC20 _tokenBase,
    IERC20 _tokenQuote, 
    int24 _tick0,
    int24 _tick1,
    int24 _tick2
  ) external {
    require(msg.sender == launchpad, "!launchpad");
    require(launchParams[_tokenBase].pool == IClPool(address(0)), "!launched");

    uint160 sqrtPriceX96Launch = TickMath.getSqrtPriceAtTick(_tick0 - 1);
    uint160 sqrtPriceX960 = TickMath.getSqrtPriceAtTick(_tick0);
    uint160 sqrtPriceX961 = TickMath.getSqrtPriceAtTick(_tick1);
    uint160 sqrtPriceX962 = TickMath.getSqrtPriceAtTick(_tick2);

    IClPool pool = IClPool(clPoolFactory.createPool(
      address(_tokenBase),
      address(_tokenQuote),
      10_000,
      sqrtPriceX96Launch
    ));

    _tokenBase.approve(address(pool), type(uint256).max);
    _tokenQuote.approve(address(pool), type(uint256).max);

    uint256 balance = _tokenBase.balanceOf(address(this));
    require(balance > 0, "!balance");

    _transientClPool = pool;

    // Add liquidity in 3 ranges
    uint128 liquidity0 = LiquidityAmounts.getLiquidityForAmount0(
      sqrtPriceX960,
      sqrtPriceX961,
      balance / 2
    );

    pool.mint(
      _me,
      _tick0,
      _tick1,
      liquidity0,
      abi.encode(address(_tokenBase))
    );

    uint128 liquidity1 = LiquidityAmounts.getLiquidityForAmount0(
      sqrtPriceX961,
      sqrtPriceX962,
      balance / 4
    );

    pool.mint(
      _me,
      _tick1,
      _tick2,
      liquidity1,
      abi.encode(address(_tokenBase))
    );

    launchParams[_tokenBase] = LaunchTokenParams({
      pool: pool,
      poolKey: PoolKey({
        currency0: Currency.wrap(address(_tokenBase)),
        currency1: Currency.wrap(address(_tokenQuote)),
        fee: 10_000,
        hooks: IHooks(address(0)),
        tickSpacing: pool.tickSpacing()
      }),
      tick0: _tick0,
      tick1: _tick1,
      tick2: _tick2
    });
  }

  function swapForExactInput(
    IERC20 _tokenIn,
    IERC20 _tokenOut,
    uint256 _amountIn,
    uint256 _minAmountOut,
    uint256 _deadline
  ) external returns (uint256 amountOut) {
    _tokenIn.approve(address(swapRouter), _amountIn);

    IPancakeSwapRouter.ExactInputSingleParams memory params = IPancakeSwapRouter
      .ExactInputSingleParams({
        tokenIn: address(_tokenIn),
        tokenOut: address(_tokenOut),
        fee: 10_000,
        recipient: msg.sender,
        amountIn: _amountIn,
        amountOutMinimum: _minAmountOut,
        sqrtPriceLimitX96: 0
      });

    amountOut = swapRouter.exactInputSingle(params);
  }

  function swapForExactOutput(
    IERC20 _tokenIn,
    IERC20 _tokenOut,
    uint256 _amountOut,
    uint256 _maxAmountIn,
    uint256 _deadline
  ) external returns (uint256 amountIn) {
    _tokenIn.approve(address(swapRouter), _maxAmountIn);

    IPancakeSwapRouter.ExactOutputSingleParams memory params = IPancakeSwapRouter
      .ExactOutputSingleParams({
        tokenIn: address(_tokenIn),
        tokenOut: address(_tokenOut),
        fee: 10_000,
        recipient: msg.sender,
        amountOut: _amountOut,
        amountInMaximum: _maxAmountIn,
        sqrtPriceLimitX96: 0
      });

    amountIn = swapRouter.exactOutputSingle(params);
  }

  function claimFees(address _token) external returns (uint256 fee0, uint256 fee1) {
    LaunchTokenParams memory params = launchParams[IERC20(_token)];
    require(address(params.pool) != address(0), "!launched");
    
    (fee0, fee1) = params.pool.collectProtocolFees(
      _me,
      type(uint128).max,
      type(uint128).max
    );
  }

  function pancakeV3SwapCallback(
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) external {
    require(msg.sender == address(_transientClPool));
    address token = abi.decode(data, (address));
    if (amount0Delta > 0) IERC20(token).transfer(msg.sender, uint256(amount0Delta));
    if (amount1Delta > 0) IERC20(token).transfer(msg.sender, uint256(amount1Delta));
  }
}