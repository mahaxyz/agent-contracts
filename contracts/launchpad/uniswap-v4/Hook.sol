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

import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IAgentToken} from "contracts/interfaces/IAgentToken.sol";
import {Launchpad} from "contracts/launchpad/uniswap-v4/Launchpad.sol";
import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";

import {Hooks} from "lib/v4-core/src/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "lib/v4-core/src/types/PoolId.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {BaseHook} from "lib/v4-periphery/src/utils/BaseHook.sol";

import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

struct PoolConfig {
  address token;
  int24 fundraiseUpperTick;
  bool graduated;
}

contract Hook is BaseHook {
  using PoolIdLibrary for PoolKey;
  using StateLibrary for IPoolManager;

  mapping(PoolId => PoolConfig) public poolConfigs;
  Launchpad public immutable launchpad;

  // Event definition
  event PoolGraduated(PoolId indexed poolId, address token);

  constructor(IPoolManager _poolManager, Launchpad _launchpad) BaseHook(_poolManager) {
    launchpad = _launchpad;
  }

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

  function _afterInitialize(address, PoolKey calldata key, uint160, int24) internal override returns (bytes4) {
    // Get pool configuration from launchpad
    (int24 lowerTick, int24 upperTick, bool graduated, address token,,,) = launchpad.pools(key.toId());

    poolConfigs[key.toId()] = PoolConfig({token: token, fundraiseUpperTick: upperTick, graduated: graduated});

    return this.afterInitialize.selector;
  }

  function _afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
    internal
    override
    returns (bytes4, int128)
  {
    PoolId poolId = key.toId();
    PoolConfig memory config = poolConfigs[poolId];

    if (!config.graduated) {
      (, int24 currentTick,,) = poolManager.getSlot0(poolId);

      if (currentTick >= config.fundraiseUpperTick) {
        _graduatePool(poolId, key);
        poolConfigs[poolId].graduated = true;
      }
    }

    return (this.afterSwap.selector, int128(0));
  }

  function _beforeSwap(
    address sender,
    PoolKey calldata key,
    IPoolManager.SwapParams calldata params,
    bytes calldata hookData
  ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
    // Get the token address from the pool configuration
    PoolId poolId = key.toId();
    PoolConfig memory config = poolConfigs[poolId];

    // Check for if the sender is whitelist in the Agent Token
    bool isWhitelisted = IAgentToken(config.token).isWhitelisted(sender);
    // If sender is whitelist set fee zero for him / her
    if (isWhitelisted) {
      return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }
    uint24 fee = 3000 | LPFeeLibrary.OVERRIDE_FEE_FLAG;
    return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee);
  }

  function _graduatePool(PoolId poolId, PoolKey memory key) private {
    // Trigger graduation in launchpad
    (,,, address token,,,) = launchpad.pools(poolId);
    launchpad.graduate(poolId);
    emit PoolGraduated(poolId, token);
  }
}
