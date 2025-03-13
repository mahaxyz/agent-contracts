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

pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {AgentLaunchpad} from "contracts/launchpad/clmm/AgentLaunchpad.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "lib/v4-core/src/types/BeforeSwapDelta.sol";
import {PoolId, PoolIdLibrary} from "lib/v4-core/src/types/PoolId.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {BaseHook} from "lib/v4-periphery/src/utils/BaseHook.sol";

contract LaunchpadHook is BaseHook {
  using PoolIdLibrary for PoolKey;

  mapping(PoolId => int24) public tickUpperLast;
  mapping(PoolId => int24) public tickLowerLast;
  mapping(address => bool) public whitelist;
  AgentLaunchpad public launchpad;

  constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

  function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
    return Hooks.Permissions({
      beforeInitialize: false,
      afterInitialize: true,
      beforeAddLiquidity: false,
      afterAddLiquidity: false,
      beforeRemoveLiquidity: false,
      afterRemoveLiquidity: false,
      beforeSwap: true,
      afterSwap: true,
      beforeDonate: false,
      afterDonate: false,
      beforeSwapReturnDelta: true,
      afterSwapReturnDelta: false,
      afterAddLiquidityReturnDelta: false,
      afterRemoveLiquidityReturnDelta: false
    });
  }

  function _afterInitialize(address sender, PoolKey calldata poolKey, uint160 sqrtPriceX96, int24 tick)
    internal
    override
    returns (bytes4)
  {
    uint24 INITIAL_FEE = 3000; // 0.30$
    poolManager.updateDynamicLPFee(poolKey, INITIAL_FEE);

    return this.afterInitialize.selector;
  }

  function _beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
    internal
    override
    returns (bytes4, BeforeSwapDelta, uint24)
  {
    // TODO: Check if user is whitelisted or not and apply the fee accordingly
    uint24 newFee = calculateFee() | LPFeeLibrary.OVERRIDE_FEE_FLAG;
    return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, newFee);
  }

  function calculateFee() internal view returns (uint24) {
    //TODO: calculate fee based on the market conditions
    return 3000;
  }

  function _afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
    internal
    override
    returns (bytes4, int128)
  {
    //TODO: triger hook Once the price crosses the upper tick
    return (this.afterSwap.selector, int128(0));
  }

  // Complete the sale and redistribute liquidity
  // TODO: Implement this function to migrate liquidity to the new pool
  // function _completeSale(PoolKey calldata key) internal {
  //     // 1. Withdraw all existing liquidity from the pool
  //     poolManager.burnLiquidity(key, type(uint128).max, address(this));

  //     // 2. Collect remaining unsold tokens
  //     (uint256 token0Amount, uint256 token1Amount) = poolManager.collectFees(key, address(this));

  //     // 3. Re-add liquidity across full range
  //     poolManager.mintLiquidity(key, type(int24).min, type(int24).max, token0Amount, token1Amount, address(this));

  //     // 4. Lock LP tokens
  //     lockedLP[address(this)] += token0Amount + token1Amount;

  //     emit LiquidityMigrated(key);
  // }
}
