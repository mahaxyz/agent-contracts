// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝    ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Telegram: https://t.me/mahaxyz
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IWETH9} from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";
import {ICLMMAdapter, PoolKey} from "contracts/interfaces/ICLMMAdapter.sol";
import {IFreeUniV3LPLocker} from "contracts/interfaces/IFreeUniV3LPLocker.sol";
import {ICLSwapRouter} from "contracts/interfaces/thirdparty/ICLSwapRouter.sol";
import {IClPool} from "contracts/interfaces/thirdparty/IClPool.sol";
import {IClPoolFactory} from "contracts/interfaces/thirdparty/IClPoolFactory.sol";

import {INonfungiblePositionManager} from "contracts/interfaces/thirdparty/INonfungiblePositionManager.sol";

abstract contract BaseV3Adapter is ICLMMAdapter, Initializable {
  using SafeERC20 for IERC20;

  address internal _me;
  address public launchpad;
  IClPoolFactory public clPoolFactory;
  ICLSwapRouter public swapRouter;
  IFreeUniV3LPLocker public locker;
  INonfungiblePositionManager public nftPositionManager;
  IWETH9 public WETH9;

  uint24 internal fee;
  int24 internal tickSpacing;

  mapping(IERC20 token => LaunchTokenParams params) public launchParams;
  mapping(IERC20 token => uint256 lockId) public tokenToLockId0;
  mapping(IERC20 token => uint256 lockId) public tokenToLockId1;

  function __BaseV3Adapter_init(
    address _launchpad,
    address _WETH9,
    address _locker,
    address _swapRouter,
    address _nftPositionManager,
    address _clPoolFactory,
    uint24 _fee,
    int24 _tickSpacing
  ) internal {
    launchpad = _launchpad;
    _me = address(this);
    WETH9 = IWETH9(_WETH9);
    locker = IFreeUniV3LPLocker(_locker);
    swapRouter = ICLSwapRouter(_swapRouter);
    nftPositionManager = INonfungiblePositionManager(_nftPositionManager);
    clPoolFactory = IClPoolFactory(_clPoolFactory);
    fee = _fee;
    tickSpacing = _tickSpacing;
  }

  /// @inheritdoc ICLMMAdapter
  function launchedTokens(IERC20 _token) external view returns (bool launched) {
    launched = launchParams[_token].pool != address(0);
  }

  /// @inheritdoc ICLMMAdapter
  function getPool(IERC20 _token) external view returns (address pool) {
    return address(launchParams[_token].pool);
  }

  /// @inheritdoc ICLMMAdapter
  function swapWithExactOutput(IERC20 _tokenIn, IERC20 _tokenOut, uint256 _amountOut, uint256 _maxAmountIn)
    external
    returns (uint256 amountIn)
  {
    _tokenIn.safeTransferFrom(msg.sender, address(this), _maxAmountIn);
    _tokenIn.approve(address(swapRouter), type(uint256).max);
    amountIn = swapRouter.exactOutputSingle(
      ICLSwapRouter.ExactOutputSingleParams({
        tokenIn: address(_tokenIn),
        tokenOut: address(_tokenOut),
        amountOut: _amountOut,
        recipient: msg.sender,
        deadline: block.timestamp,
        fee: fee,
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
      ICLSwapRouter.ExactInputSingleParams({
        tokenIn: address(_tokenIn),
        tokenOut: address(_tokenOut),
        amountIn: _amountIn,
        recipient: msg.sender,
        deadline: block.timestamp,
        fee: fee,
        amountOutMinimum: _minAmountOut,
        sqrtPriceLimitX96: 0
      })
    );
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
        fee: fee,
        tickSpacing: tickSpacing,
        hooks: IHooks(address(0))
      });
      launchParams[_tokenBase] = LaunchTokenParams({
        pool: address(pool),
        poolKey: poolKey,
        tick0: _tick0,
        tick1: _tick1,
        tick2: _tick2,
        tokenBase: _tokenBase,
        tokenQuote: _tokenQuote
      });
    }

    // calculate and add liquidity for the various tick ranges
    {
      uint128 liquidityBeforeTick0 =
        LiquidityAmounts.getLiquidityForAmount0(sqrtPriceX960, sqrtPriceX961, 600_000_000 ether);
      uint256 lockId0 = _mint(_me, _tick0, _tick1, liquidityBeforeTick0);
      tokenToLockId0[IERC20(_tokenBase)] = lockId0;
    }
    {
      uint128 liquidityBeforeTick1 =
        LiquidityAmounts.getLiquidityForAmount0(sqrtPriceX961, sqrtPriceX962, 400_000_000 ether);
      uint256 lockId1 = _mint(_me, _tick1, _tick2, liquidityBeforeTick1);
      tokenToLockId1[IERC20(_tokenBase)] = lockId1;
    }
  }

  /// @inheritdoc ICLMMAdapter
  function claimFees(address _token) external returns (uint256 fee0, uint256 fee1) {
    require(msg.sender == launchpad, "!launchpad");
    LaunchTokenParams memory params = launchParams[IERC20(_token)];

    uint256 lockId0 = tokenToLockId0[IERC20(_token)];
    uint256 lockId1 = tokenToLockId1[IERC20(_token)];

    (uint256 fee00, uint256 fee01) = locker.collect(lockId0, _me, type(uint128).max, type(uint128).max);
    (uint256 fee10, uint256 fee11) = locker.collect(lockId1, _me, type(uint128).max, type(uint128).max);

    fee0 = fee00 + fee10;
    fee1 = fee01 + fee11;

    params.tokenBase.transfer(msg.sender, fee0);
    params.tokenQuote.transfer(msg.sender, fee1);
  }

  /// @inheritdoc ICLMMAdapter
  function graduated(address token) external view returns (bool) {
    LaunchTokenParams memory params = launchParams[IERC20(token)];
    if (params.pool == address(0)) return false;
    (, int24 tick,,,,,) = IClPool(params.pool).slot0();
    return tick >= params.tick1;
  }

  /// @dev Refund tokens to the owner
  /// @param _token The token to refund
  function _refundTokens(IERC20 _token) internal {
    uint256 remaining = _token.balanceOf(address(this));
    if (remaining == 0) return;
    _token.safeTransfer(msg.sender, remaining);
  }

  /// @dev Mint a position and lock it forever
  /// @param _token The token to mint the position for
  /// @param _tick0 The lower tick of the position
  /// @param _tick1 The upper tick of the position
  /// @param _liquidityBeforeTick0 The liquidity before the tick0
  /// @return lockId The lock id of the position
  function _mint(address _token, int24 _tick0, int24 _tick1, uint256 _liquidityBeforeTick0)
    internal
    returns (uint256 lockId)
  {
    // mint the position
    INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
      token0: address(_token),
      token1: address(_token),
      fee: 10_000,
      tickLower: _tick0,
      tickUpper: _tick1,
      amount0Desired: _liquidityBeforeTick0,
      amount1Desired: 0,
      amount0Min: _liquidityBeforeTick0,
      amount1Min: 0,
      recipient: _me,
      deadline: block.timestamp
    });

    (uint256 tokenId,,,) = nftPositionManager.mint(params);

    // lock the liquidity forever; allow this contract to collect fees
    lockId = locker.lock(nftPositionManager, tokenId, address(0), _me, type(uint256).max);
  }

  receive() external payable {}
}
