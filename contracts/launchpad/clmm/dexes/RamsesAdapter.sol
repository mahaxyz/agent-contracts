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
import {IAgentToken} from "contracts/interfaces/IAgentToken.sol";
import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";

import {IClPool} from "contracts/interfaces/thirdparty/IClPool.sol";
import {IClPoolFactory} from "contracts/interfaces/thirdparty/IClPoolFactory.sol";
import {IRamsesV2MintCallback} from "contracts/interfaces/thirdparty/pool/IRamsesV2MintCallback.sol";

import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

contract RamsesAdapter is ICLMMAdapter, IRamsesV2MintCallback, Initializable {
  IClPoolFactory public clPoolFactory;
  address public launchpad;
  mapping(IERC20 token => LaunchTokenParams params) public launchParams;

  address private _me;
  IClPool private _transientClPool;

  struct LaunchTokenParams {
    IERC20 tokenBase;
    IERC20 tokenQuote;
    IClPool pool;
    uint24 fee;
    int24 tick0;
    int24 tick1;
    int24 tick2;
  }

  function initialize(address _launchpad, address _clPoolFactory) external initializer {
    launchpad = _launchpad;
    clPoolFactory = IClPoolFactory(_clPoolFactory);
    _me = address(this);
  }

  function launchedTokens(IERC20 _token) external view returns (bool launched) {
    launched = launchParams[_token].pool != IClPool(address(0));
  }

  function addSingleSidedLiquidity(
    IERC20 _tokenBase,
    IERC20 _tokenQuote,
    uint24 _fee,
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

    uint256 amountBaseBeforeTick = 600_000_000 ether;
    uint256 amountBaseAfterTick = 400_000_000 ether;

    IClPool pool =
      IClPool(clPoolFactory.createPool(address(_tokenBase), address(_tokenQuote), _fee, sqrtPriceX96Launch));
    launchParams[_tokenBase] = LaunchTokenParams({
      tokenBase: _tokenBase,
      tokenQuote: _tokenQuote,
      pool: pool,
      fee: _fee,
      tick0: _tick0,
      tick1: _tick1,
      tick2: _tick2
    });
    require(address(_tokenBase) == pool.token0(), "!token0");
    IAgentToken(address(_tokenBase)).whitelist(address(pool));

    // calculate the liquidity for the various tick ranges
    uint128 liquidityBeforeTick0 =
      LiquidityAmounts.getLiquidityForAmount0(sqrtPriceX960, sqrtPriceX961, amountBaseBeforeTick);
    uint128 liquidityBeforeTick1 =
      LiquidityAmounts.getLiquidityForAmount0(sqrtPriceX961, sqrtPriceX962, amountBaseAfterTick);

    // add liquidity to the various tick ranges
    _transientClPool = pool;
    pool.mint(_me, _tick0, _tick1, liquidityBeforeTick0, "");
    pool.mint(_me, _tick1, _tick2, liquidityBeforeTick1, "");
    _transientClPool = IClPool(address(0));
  }

  function claimFees(address _token) external returns (uint256 fee0, uint256 fee1) {
    require(msg.sender == launchpad, "!launchpad");
    LaunchTokenParams memory params = launchParams[IERC20(_token)];
    require(params.pool != IClPool(address(0)), "!launched");

    (uint256 fee00, uint256 fee01) =
      params.pool.collect(_me, params.tick0, params.tick1, type(uint128).max, type(uint128).max);
    (uint256 fee10, uint256 fee11) =
      params.pool.collect(_me, params.tick1, params.tick2, type(uint128).max, type(uint128).max);

    fee0 = fee00 + fee10;
    fee1 = fee01 + fee11;

    IERC20(params.pool.token0()).transfer(msg.sender, fee0);
    IERC20(params.pool.token1()).transfer(msg.sender, fee1);
  }

  function ramsesV2MintCallback(uint256 amount0, uint256, bytes calldata) external {
    require(msg.sender == address(_transientClPool) && address(_transientClPool) != address(0), "!clPool");
    IERC20(_transientClPool.token0()).transferFrom(launchpad, msg.sender, amount0);
  }

  function graduated(address token) external view returns (bool) {
    LaunchTokenParams memory params = launchParams[IERC20(token)];
    if (params.pool == IClPool(address(0))) return false;
    (, int24 tick,,,,,) = params.pool.slot0();
    return tick >= params.tick1;
  }
}
