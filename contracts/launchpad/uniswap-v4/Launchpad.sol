// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.26;

import {IAgentToken} from "../../interfaces/IAgentToken.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {LPFeeLibrary} from "lib/v4-core/src/libraries/LPFeeLibrary.sol";
import {TickMath} from "lib/v4-core/src/libraries/TickMath.sol";
import {Currency, CurrencyLibrary} from "lib/v4-core/src/types/Currency.sol";

import {PoolId, PoolIdLibrary} from "lib/v4-core/src/types/PoolId.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {LiquidityAmounts} from "lib/v4-core/test/utils/LiquidityAmounts.sol";

struct CreateParams {
  string name;
  string symbol;
  string metadata;
  IERC20 fundingToken;
  uint256 goal;
  uint256 tokensToSell;
  bytes32 salt;
  address bondingCurve;
  uint256 limitPerWallet;
  uint160 initialSqrtPrice;
  int24 lowerTick;
  int24 upperTick;
}

struct PoolInfo {
  int24 fundraiseLowerTick;
  int24 fundraiseUpperTick;
  bool graduated;
  address token;
  uint128 lowerLiquidity; // Liquidity in initial lower range
  uint128 upperLiquidity; // Liquidity in initial upper range
  bool isToken0;
}

contract Launchpad is OwnableUpgradeable {
  using CurrencyLibrary for Currency;
  using PoolIdLibrary for PoolKey;

  address public odos;
  address public tokenImplementation;
  IHooks public hook;
  IPoolManager public poolManager;

  mapping(PoolId => PoolInfo) public pools;
  // Add mapping to track PoolKey by PoolId
  mapping(PoolId => PoolKey) public poolKeys;

  function initialize(address _odos, address _tokenImplementation, address _owner, address _hook, address _poolManager)
    external
    initializer
  {
    odos = _odos;
    tokenImplementation = _tokenImplementation;
    hook = IHooks(_hook);
    poolManager = IPoolManager(_poolManager);
    __Ownable_init(_owner);
  }

  function create(CreateParams memory p) external returns (address) {
    require(p.lowerTick < p.upperTick, "Invalid tick range");
    require(p.upperTick < TickMath.MAX_TICK, "Upper tick too high");
    address[] memory whitelisted = new address[](2);
    whitelisted[0] = odos;
    whitelisted[1] = address(this);
    // Token Creation
    IAgentToken.InitParams memory params = IAgentToken.InitParams({
      name: p.name,
      symbol: p.symbol,
      metadata: p.metadata,
      whitelisted: whitelisted,
      limitPerWallet: p.limitPerWallet
    });

    IAgentToken token = IAgentToken(Clones.cloneDeterministic(tokenImplementation, p.salt));

    token.initialize(params);

    (PoolKey memory poolKey, bool isToken0) = _createPool(address(p.fundingToken), address(token), p.initialSqrtPrice);
    PoolId Id = poolKey.toId();
    poolKeys[Id] = poolKey; // Store PoolKey
    pools[Id].token = address(token);
    pools[Id].fundraiseUpperTick = p.upperTick;
    pools[Id].fundraiseLowerTick = p.lowerTick;
    pools[Id].graduated = false;
    pools[Id].isToken0 = isToken0; // Store token order

    _addLiquidity(poolKey, isToken0, p.tokensToSell, p.lowerTick, p.upperTick, TickMath.MAX_TICK);

    return address(token);
  }

  function graduate(PoolId Id) external {
    // Hook contract can graduate tokens
    require(msg.sender == address(hook), "Only Hook!");
    PoolInfo storage pool = pools[Id];
    require(!pool.graduated, "Already graduated");
    PoolKey memory poolKey = poolKeys[Id];

    // 1. Determine funding currency
    Currency fundingCurrency = pool.isToken0 ? poolKey.currency0 : poolKey.currency1;
    address fundingTokenAddress = Currency.unwrap(fundingCurrency);

    // 2. Sync currency balance before operation
    poolManager.sync(fundingCurrency);

    // 3. Remove liquidity from original range
    IPoolManager.ModifyLiquidityParams memory removeParams = IPoolManager.ModifyLiquidityParams({
      tickLower: pool.fundraiseLowerTick,
      tickUpper: pool.fundraiseUpperTick,
      liquidityDelta: -int128(pool.lowerLiquidity),
      salt: bytes32(0)
    });
    (BalanceDelta delta,) = poolManager.modifyLiquidity(poolKey, removeParams, "");

    // 4. Settle balances
    poolManager.settle(); // No parameters needed
    uint256 fundingAmount = IERC20(fundingTokenAddress).balanceOf(address(this));

    // 5. Calculate new ticks (0 to original upper)
    int24 newLowerTick = TickMath.MIN_TICK; // Frontend should provide exact
    (uint160 sqrtLower, uint160 sqrtUpper) =
      (TickMath.getSqrtPriceAtTick(newLowerTick), TickMath.getSqrtPriceAtTick(pool.fundraiseUpperTick));

    // 6. Calculate new liquidity
    uint128 newLiquidity = pool.isToken0
      ? LiquidityAmounts.getLiquidityForAmount1(sqrtLower, sqrtUpper, fundingAmount)
      : LiquidityAmounts.getLiquidityForAmount0(sqrtLower, sqrtUpper, fundingAmount);

    require(newLiquidity > 0, "Insufficient liquidity");

    // 7. Approve and add new liquidity
    IERC20(fundingTokenAddress).approve(address(poolManager), fundingAmount);
    IPoolManager.ModifyLiquidityParams memory addParams = IPoolManager.ModifyLiquidityParams({
      tickLower: newLowerTick,
      tickUpper: pool.fundraiseUpperTick,
      liquidityDelta: int128(newLiquidity),
      salt: bytes32(0)
    });
    poolManager.modifyLiquidity(poolKey, addParams, "");

    // 8. Update state
    pool.fundraiseLowerTick = newLowerTick;
    pool.lowerLiquidity = newLiquidity;

    // 9. Graduate the token
    pool.graduated = true;
  }

  function _createPool(address _token0, address _token1, uint160 _initialSqrtPrice)
    private
    returns (PoolKey memory poolKey, bool isToken0)
  {
    // Sort the tokens firsts
    (address currency0, address currency1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);

    isToken0 = (_token0 == currency0);
    // Creating Uniswap v4 pool
    poolKey = PoolKey({
      currency0: Currency.wrap(currency0),
      currency1: Currency.wrap(currency1),
      fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
      tickSpacing: 1, // for tight price range
      hooks: hook
    });

    poolManager.initialize(poolKey, _initialSqrtPrice);

    return (poolKey, isToken0);
  }

  function _addLiquidity(
    PoolKey memory poolKey,
    bool isToken0,
    uint256 totalTokens,
    int24 lowerTick,
    int24 upperTick,
    int24 upperMaxTick
  ) private {
    // Transfer tokens from creator to contract
    IERC20(Currency.unwrap(poolKey.currency0)).transferFrom(msg.sender, address(this), totalTokens);

    // Approve PoolManager to spend tokens
    IERC20(Currency.unwrap(poolKey.currency0)).approve(address(poolManager), totalTokens);

    // Split liquidity 60/40
    uint256 tokensForLower = (totalTokens * 60) / 100;
    uint256 tokensForUpper = totalTokens - tokensForLower;

    PoolId Id = poolKey.toId();

    // 60% Supply range in lower-upper
    pools[Id].lowerLiquidity = _addLiquidityToRange(poolKey, isToken0, lowerTick, upperTick, tokensForLower);

    // 40% Supply range in upper to infinite
    pools[Id].upperLiquidity = _addLiquidityToRange(poolKey, isToken0, upperTick, upperMaxTick, tokensForUpper);
  }

  function _addLiquidityToRange(PoolKey memory poolKey, bool isToken0, int24 tickLower, int24 tickUpper, uint256 amount)
    private
    returns (uint128)
  {
    uint160 sqrtLower = TickMath.getSqrtPriceAtTick(tickLower);
    uint160 sqrtUpper = TickMath.getSqrtPriceAtTick(tickUpper);

    uint128 liquidity;
    if (isToken0) {
      liquidity = LiquidityAmounts.getLiquidityForAmount0(sqrtLower, sqrtUpper, amount);
    } else {
      liquidity = LiquidityAmounts.getLiquidityForAmount1(sqrtLower, sqrtUpper, amount);
    }
    require(liquidity > 0, "Insufficient liquidity");

    poolManager.modifyLiquidity(
      poolKey,
      IPoolManager.ModifyLiquidityParams({
        tickLower: tickLower,
        tickUpper: tickUpper,
        liquidityDelta: int128(liquidity),
        salt: bytes32(0)
      }),
      abi.encode(amount, 0) // Single-sided liquidity (only token0)
    );
    return liquidity;
  }
}
