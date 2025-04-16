// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝    ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://wagmie.com
// Telegram: https://t.me/mahaxyz
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IWETH9} from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";
import {ICLMMAdapter, IClPool, PoolKey} from "contracts/interfaces/ICLMMAdapter.sol";
import {ICLSwapRouter} from "contracts/interfaces/thirdparty/ICLSwapRouter.sol";
import {IClPoolFactory} from "contracts/interfaces/thirdparty/IClPoolFactory.sol";

import "forge-std/console.sol";

abstract contract BaseV3Adapter is ICLMMAdapter, Initializable {
  using SafeERC20 for IERC20;

  address internal _me;
  address public launchpad;
  IClPoolFactory public clPoolFactory;
  ICLSwapRouter public swapRouter;
  address public locker;
  IERC721 public nftPositionManager;
  IWETH9 public WETH9;

  mapping(IERC20 token => LaunchTokenParams params) public launchParams;
  mapping(IERC20 token => mapping(uint256 index => uint256 lockId)) public tokenToLockId;

  function __BaseV3Adapter_init(
    address _launchpad,
    address _WETH9,
    address _locker,
    address _swapRouter,
    address _nftPositionManager,
    address _clPoolFactory
  ) internal {
    _me = address(this);

    clPoolFactory = IClPoolFactory(_clPoolFactory);
    launchpad = _launchpad;
    locker = _locker;
    nftPositionManager = IERC721(_nftPositionManager);
    swapRouter = ICLSwapRouter(_swapRouter);
    WETH9 = IWETH9(_WETH9);

    nftPositionManager.setApprovalForAll(address(locker), true);
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
  function swapWithExactOutput(IERC20 _tokenIn, IERC20 _tokenOut, uint256 _amountOut, uint256 _maxAmountIn, uint24 _fee)
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
        fee: _fee,
        amountInMaximum: _maxAmountIn,
        sqrtPriceLimitX96: 0
      })
    );
    _refundTokens(_tokenIn);
  }

  /// @inheritdoc ICLMMAdapter
  function swapWithExactInput(IERC20 _tokenIn, IERC20 _tokenOut, uint256 _amountIn, uint256 _minAmountOut, uint24 _fee)
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
        fee: _fee,
        amountOutMinimum: _minAmountOut,
        sqrtPriceLimitX96: 0
      })
    );
  }

  /// @inheritdoc ICLMMAdapter
  function addSingleSidedLiquidity(
    IERC20 _tokenBase,
    IERC20 _tokenQuote,
    int24 _tick0,
    int24 _tick1,
    int24 _tick2,
    uint24 _fee,
    int24 _tickSpacing,
    uint256 _totalAmount,
    uint256 _graduationAmount
  ) external {
    require(msg.sender == launchpad, "!launchpad");
    require(launchParams[_tokenBase].pool == address(0), "!launched");

    uint160 sqrtPriceX96Launch = TickMath.getSqrtPriceAtTick(_tick0 - 1);

    IClPool pool = _createPool(_tokenBase, _tokenQuote, _fee, sqrtPriceX96Launch);

    PoolKey memory poolKey = PoolKey({
      currency0: Currency.wrap(address(_tokenBase)),
      currency1: Currency.wrap(address(_tokenQuote)),
      fee: _fee,
      tickSpacing: _tickSpacing,
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

    // calculate and add liquidity for the various tick ranges
    _tokenBase.safeTransferFrom(msg.sender, address(this), _totalAmount);
    _mintAndLock(_tokenBase, _tokenQuote, _tick0, _tick1, _fee, _graduationAmount, 0);
    _mintAndLock(_tokenBase, _tokenQuote, _tick1, _tick2, _fee, _totalAmount - _graduationAmount, 1);
  }

  /// @inheritdoc ICLMMAdapter
  function claimFees(address _token) external returns (uint256 fee0, uint256 fee1) {
    require(msg.sender == launchpad, "!launchpad");
    LaunchTokenParams memory params = launchParams[IERC20(_token)];

    uint256 lockId0 = tokenToLockId[IERC20(_token)][0];
    uint256 lockId1 = tokenToLockId[IERC20(_token)][1];

    (uint256 fee00, uint256 fee01) = _collectFees(lockId0);
    (uint256 fee10, uint256 fee11) = _collectFees(lockId1);

    fee0 = fee00 + fee10;
    fee1 = fee01 + fee11;

    params.tokenBase.transfer(msg.sender, fee0);
    params.tokenQuote.transfer(msg.sender, fee1);
  }

  /// @dev Refund tokens to the owner
  /// @param _token The token to refund
  function _refundTokens(IERC20 _token) internal {
    uint256 remaining = _token.balanceOf(address(this));
    if (remaining == 0) return;
    _token.safeTransfer(msg.sender, remaining);
  }

  /// @dev Mint a position and lock it forever
  /// @param _token0 The token to mint the position for
  /// @param _token1 The token to mint the position for
  /// @param _tick0 The lower tick of the position
  /// @param _tick1 The upper tick of the position
  /// @param _fee The fee of the pool
  /// @param _amount0 The amount of tokens to mint the position for
  /// @return lockId The lock id of the position
  function _mintAndLock(
    IERC20 _token0,
    IERC20 _token1,
    int24 _tick0,
    int24 _tick1,
    uint24 _fee,
    uint256 _amount0,
    uint256 _index
  ) internal virtual returns (uint256 lockId);

  function _collectFees(uint256 _lockId) internal virtual returns (uint256 fee0, uint256 fee1);

  /// @dev Mint a position
  /// @param _token0 The token to mint the position for
  /// @param _token1 The token to mint the position for
  /// @param _tick0 The lower tick of the position
  /// @param _tick1 The upper tick of the position
  /// @param _amount0 The amount of tokens to mint the position for
  /// @return tokenId The token id of the position
  function _mint(IERC20 _token0, IERC20 _token1, int24 _tick0, int24 _tick1, uint24 _fee, uint256 _amount0)
    internal
    virtual
    returns (uint256 tokenId);

  /// @dev Create a pool
  /// @param _token0 The token to create the pool for
  /// @param _token1 The token to create the pool for
  /// @param _fee The fee of the pool
  /// @param _sqrtPriceX96Launch The sqrt price of the pool
  /// @return pool The address of the pool
  function _createPool(IERC20 _token0, IERC20 _token1, uint24 _fee, uint160 _sqrtPriceX96Launch)
    internal
    virtual
    returns (IClPool pool);

  receive() external payable {}
}
