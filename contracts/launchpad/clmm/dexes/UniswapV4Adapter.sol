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

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {ICLMMAdapter, IERC20} from "contracts/interfaces/ICLMMAdapter.sol";

abstract contract UniswapV4Adapter is ICLMMAdapter, BaseHook {
  using PoolIdLibrary for PoolKey;
  using StateLibrary for IPoolManager;

  address public launchpad;
  mapping(IERC20 token => LaunchTokenParams params) public launchParams;

  constructor(address _launchpad, address _poolManager) {
    launchpad = _launchpad;
    poolManager = IPoolManager(_poolManager);
  }

  function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
    return Hooks.Permissions({
      beforeInitialize: false,
      afterInitialize: false,
      beforeAddLiquidity: false,
      afterAddLiquidity: false,
      beforeRemoveLiquidity: false,
      afterRemoveLiquidity: false,
      beforeSwap: false,
      afterSwap: true,
      beforeDonate: false,
      afterDonate: false,
      beforeSwapReturnDelta: false,
      afterSwapReturnDelta: false,
      afterAddLiquidityReturnDelta: false,
      afterRemoveLiquidityReturnDelta: false
    });
  }

  function _afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
    internal
    pure
    override
    returns (bytes4, int128)
  {
    require(key.currency0 == Currency.wrap(address(0)) && key.currency1 == Currency.wrap(address(0)), "!poolId");

    // PoolId poolId = key.toId();
    // if (!config.graduated) {
    //   (, int24 currentTick,,) = poolManager.getSlot0(poolId);
    //   if (currentTick >= config.fundraiseUpperTick) {
    //     _graduatePool(poolId, key);
    //     poolConfigs[poolId].graduated = true;
    //   }
    // }

    return (this.afterSwap.selector, int128(0));
  }

  function claimFees(address _token) external returns (uint256 fee0, uint256 fee1) {
    require(msg.sender == launchpad, "!launchpad");
    LaunchTokenParams memory params = launchParams[IERC20(_token)];
    // require(params.pool != address(0), "!launched");

    // Get the position's fees from the PoolManager
    // We need to collect fees for both positions (tick ranges)
    (, BalanceDelta delta0) = poolManager.modifyLiquidity(
      params.poolKey,
      IPoolManager.ModifyLiquidityParams({
        tickLower: params.tick0,
        tickUpper: params.tick1,
        liquidityDelta: 0,
        salt: bytes32(0)
      }),
      ""
    );

    (, BalanceDelta delta1) = poolManager.modifyLiquidity(
      params.poolKey,
      IPoolManager.ModifyLiquidityParams({
        tickLower: params.tick1,
        tickUpper: params.tick2,
        liquidityDelta: 0,
        salt: bytes32(0)
      }),
      ""
    );

    // Sum up the fees from both positions
    fee0 = uint256(int256(delta0.amount0() + delta1.amount0()));
    fee1 = uint256(int256(delta0.amount1() + delta1.amount1()));

    // Transfer the collected fees to the sender
    if (fee0 > 0) params.poolKey.currency0.transfer(msg.sender, fee0);
    if (fee1 > 0) params.poolKey.currency1.transfer(msg.sender, fee1);
  }

  function swapForExactInput(IERC20 _tokenIn, IERC20 _tokenOut, uint256 _amountIn, uint256 _minAmountOut) external {
    require(msg.sender == launchpad, "!launchpad");
    // require(launchParams[_tokenIn].pool != IClPool(address(0)), "!launched");

    // _transientClPool = launchParams[_tokenIn].pool;
  }

  function graduated(address token) external view returns (bool) {
    LaunchTokenParams memory params = launchParams[IERC20(token)];
    if (params.poolKey.fee == 0) return false;
    (, int24 tick,,,,,) = params.pool.slot0();
    return tick >= params.tick1;
  }

  // function ramsesV2MintCallback(uint256 amount0, uint256, bytes calldata) external {
  //   require(msg.sender == address(_transientClPool) && address(_transientClPool) != address(0), "!clPool");
  //   IERC20(_transientClPool.token0()).transferFrom(launchpad, msg.sender, amount0);
  // }
}
