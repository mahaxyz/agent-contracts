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

    function initialize(
        address _launchpad,
        address _clPoolFactory,
        address _swapRouter,
        address _WETH9
    ) external initializer {
        launchpad = _launchpad;
        clPoolFactory = IClPoolFactory(_clPoolFactory);
        swapRouter = IPancakeSwapRouter(_swapRouter);
        _me = address(this);
        WETH9 = _WETH9;
    }

    function launchedTokens(
        IERC20 _token
    ) external view returns (bool launched) {
        launched = launchParams[_token].pool != IClPool(address(0));
    }

    function getPool(IERC20 _token) external view returns (address pool) {
        return address(launchParams[_token].pool);
    }

    /// @inheritdoc ICLMMAdapter
    function addSingleSidedLiquidity(
        IERC20 _tokenBase,
        IERC20 _tokenQuote,
        int24 _tick0,
        int24 _tick1,
        int24 _tick2
    ) external {
        require(msg.sender == launchpad, "!launchpad");
        require(
            launchParams[_tokenBase].pool == IClPool(address(0)),
            "!launched"
        );

        uint160 sqrtPriceX96Launch = TickMath.getSqrtPriceAtTick(_tick0 - 1);
        uint160 sqrtPriceX960 = TickMath.getSqrtPriceAtTick(_tick0);
        uint160 sqrtPriceX961 = TickMath.getSqrtPriceAtTick(_tick1);
        uint160 sqrtPriceX962 = TickMath.getSqrtPriceAtTick(_tick2);

        IClPool pool = IClPool(
            clPoolFactory.createPool(
                address(_tokenBase),
                address(_tokenQuote),
                10_000,
                sqrtPriceX96Launch
            )
        );

        {
            PoolKey memory poolKey = PoolKey({
                currency0: Currency.wrap(address(_tokenBase)),
                currency1: Currency.wrap(address(_tokenQuote)),
                fee: 10_000,
                tickSpacing: 200,
                hooks: IHooks(address(0))
            });
            launchParams[_tokenBase] = LaunchTokenParams({
                pool: pool,
                poolKey: poolKey,
                tick0: _tick0,
                tick1: _tick1,
                tick2: _tick2
            });
            require(address(_tokenBase) == pool.token0(), "!token0");
            ITokenTemplate(address(_tokenBase)).whitelist(address(pool));
        }

        // calculate the liquidity for the various tick ranges
        uint128 liquidityBeforeTick0 = LiquidityAmounts.getLiquidityForAmount0(
            sqrtPriceX960,
            sqrtPriceX961,
            600_000_000 ether
        );
        uint128 liquidityBeforeTick1 = LiquidityAmounts.getLiquidityForAmount0(
            sqrtPriceX961,
            sqrtPriceX962,
            400_000_000 ether
        );

        // add liquidity to the various tick ranges
        _transientClPool = pool;
        pool.mint(_me, _tick0, _tick1, liquidityBeforeTick0, "");
        pool.mint(_me, _tick1, _tick2, liquidityBeforeTick1, "");
        delete _transientClPool;
    }

    /// @inheritdoc ICLMMAdapter
    function swapForExactInput(
        IERC20 _tokenIn,
        IERC20 _tokenOut,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) external returns (uint256 amountOut) {
        require(msg.sender == launchpad, "!launchpad");
        _tokenIn.safeTransferFrom(msg.sender, address(this), _amountIn);
        _tokenIn.approve(address(swapRouter), type(uint256).max);

        IPancakeSwapRouter.ExactInputSingleParams
            memory params = IPancakeSwapRouter.ExactInputSingleParams({
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
        uint256 _maxAmountIn
    ) external returns (uint256 amountIn) {
        require(msg.sender == launchpad, "!launchpad");
        _tokenIn.safeTransferFrom(msg.sender, address(this), _maxAmountIn);
        _tokenIn.approve(address(swapRouter), type(uint256).max);

        IPancakeSwapRouter.ExactOutputSingleParams
            memory params = IPancakeSwapRouter.ExactOutputSingleParams({
                tokenIn: address(_tokenIn),
                tokenOut: address(_tokenOut),
                fee: 10_000,
                recipient: msg.sender,
                amountOut: _amountOut,
                amountInMaximum: _maxAmountIn,
                sqrtPriceLimitX96: 0
            });

        amountIn = swapRouter.exactOutputSingle(params);
        _tokenIn.safeTransfer(msg.sender, _maxAmountIn - amountIn);
    }

    /// @inheritdoc ICLMMAdapter
    function claimFees(
        address _token
    ) external returns (uint256 fee0, uint256 fee1) {
        LaunchTokenParams memory params = launchParams[IERC20(_token)];
        require(address(params.pool) != address(0), "!launched");

        (uint256 fee00, uint256 fee01) = params.pool.collect(
            _me,
            params.tick0,
            params.tick1,
            type(uint128).max,
            type(uint128).max
        );
        (uint256 fee10, uint256 fee11) = params.pool.collect(
            _me,
            params.tick1,
            params.tick2,
            type(uint128).max,
            type(uint128).max
        );

        fee0 = fee00 + fee10;
        fee1 = fee01 + fee11;

        IERC20(params.pool.token0()).transfer(msg.sender, fee0);
        IERC20(params.pool.token1()).transfer(msg.sender, fee1);
    }

    /// @inheritdoc ICLMMAdapter
    function graduated(address token) external view returns (bool) {
        LaunchTokenParams memory params = launchParams[IERC20(token)];
        if (params.pool == IClPool(address(0))) return false;
        (, int24 tick, , , , , ) = params.pool.slot0();
        return tick >= params.tick1;
    }

    function pancakeV3SwapCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        require(
            msg.sender == address(_transientClPool) &&
                address(_transientClPool) != address(0),
            "!clPool"
        );
        IERC20(_transientClPool.token0()).transferFrom(
            launchpad,
            msg.sender,
            amount0
        );
    }
}
