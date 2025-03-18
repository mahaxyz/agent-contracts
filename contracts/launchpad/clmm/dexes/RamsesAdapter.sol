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

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";

import {IClPool} from "contracts/interfaces/thirdparty/IClPool.sol";
import {IClPoolFactory} from "contracts/interfaces/thirdparty/IClPoolFactory.sol";
import {IRamsesV2MintCallback} from "contracts/interfaces/thirdparty/pool/IRamsesV2MintCallback.sol";

import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

contract RamsesAdapter is ICLMMAdapter, IRamsesV2MintCallback, Initializable {
  IClPoolFactory public CL_POOL_FACTORY;
  address public LAUNCHPAD;

  mapping(IERC20 token => LaunchTokenParams params) public launchParams;

  address private me;
  IClPool private transientClPool;

  struct LaunchTokenParams {
    IERC20 tokenBase;
    IERC20 tokenQuote;
    IClPool pool;
    uint24 fee;
    uint256 amountBaseBeforeTick;
    uint256 amountBaseAfterTick;
    uint160 sqrtPriceX96;
    int24 tick0;
    int24 tick1;
    int24 tick2;
  }

  function initialize(address _launchpad, address _clPoolFactory) external initializer {
    LAUNCHPAD = _launchpad;
    CL_POOL_FACTORY = IClPoolFactory(_clPoolFactory);
    me = address(this);
  }

  function launchedTokens(IERC20 _token) external view returns (bool launched) {
    launched = launchParams[_token].pool != IClPool(address(0));
  }

  function addSingleSidedLiquidity(
    IERC20 _tokenBase,
    IERC20 _tokenQuote,
    uint256 _amountBaseBeforeTick,
    uint256 _amountBaseAfterTick,
    uint24 _fee,
    uint160 _sqrtPriceX96,
    int24 _tick0,
    int24 _tick1,
    int24 _tick2
  ) external {
    require(msg.sender == LAUNCHPAD, "!launchpad");
    require(launchParams[_tokenBase].pool == IClPool(address(0)), "!launched");

    uint160 sqrtPriceX960 = TickMath.getSqrtPriceAtTick(_tick0);
    uint160 sqrtPriceX961 = TickMath.getSqrtPriceAtTick(_tick1);
    uint160 sqrtPriceX962 = TickMath.getSqrtPriceAtTick(_tick2);

    IClPool pool = IClPool(CL_POOL_FACTORY.createPool(address(_tokenBase), address(_tokenQuote), _fee, _sqrtPriceX96));
    launchParams[_tokenBase] = LaunchTokenParams({
      tokenBase: _tokenBase,
      tokenQuote: _tokenQuote,
      pool: pool,
      fee: _fee,
      amountBaseBeforeTick: _amountBaseBeforeTick,
      amountBaseAfterTick: _amountBaseAfterTick,
      sqrtPriceX96: sqrtPriceX960,
      tick0: _tick0,
      tick1: _tick1,
      tick2: _tick2
    });
    transientClPool = pool;

    uint128 liquidityBeforeTick0 =
      LiquidityAmounts.getLiquidityForAmount0(sqrtPriceX960, sqrtPriceX961, _amountBaseBeforeTick);
    uint128 liquidityBeforeTick1 =
      LiquidityAmounts.getLiquidityForAmount0(sqrtPriceX961, sqrtPriceX962, _amountBaseAfterTick);
    pool.mint(me, _tick0, _tick1, liquidityBeforeTick0, "");
    pool.mint(me, _tick1, _tick2, liquidityBeforeTick1, "");

    // add liquidity to the various tick ranges
    transientClPool = IClPool(address(0));
  }

  function claimFees(address _token) external returns (uint256 fee0, uint256 fee1) {
    require(msg.sender == LAUNCHPAD, "!launchpad");
    LaunchTokenParams memory params = launchParams[IERC20(_token)];
    require(params.pool != IClPool(address(0)), "!launched");

    (uint256 fee00, uint256 fee01) =
      params.pool.collect(me, params.tick0, params.tick1, type(uint128).max, type(uint128).max);
    (uint256 fee10, uint256 fee11) =
      params.pool.collect(me, params.tick1, params.tick2, type(uint128).max, type(uint128).max);

    fee0 = fee00 + fee10;
    fee1 = fee01 + fee11;

    IERC20(params.pool.token0()).transfer(msg.sender, fee0);
    IERC20(params.pool.token1()).transfer(msg.sender, fee1);
  }

  function ramsesV2MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
    require(msg.sender == address(transientClPool), "!clPool");
    if (address(transientClPool) == address(0)) return;
    if (amount0 > 0) IERC20(transientClPool.token0()).transfer(msg.sender, amount0);
    if (amount1 > 0) IERC20(transientClPool.token1()).transfer(msg.sender, amount1);
  }

  function graduated(address _token) external view returns (bool) {
    return false;
  }
}
