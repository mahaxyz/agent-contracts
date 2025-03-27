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
import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

contract UniswapV4Adapter is ICLMMAdapter, BaseHook {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    address public launchpad;
    mapping(IERC20 token => LaunchTokenParams params) public launchParams;
    address private _me;
    UniversalRouter public router;
    IPoolManager public positionManager;
    constructor(address _launchpad, address _positionManager, address _router) {
        launchpad = _launchpad;
        positionManager = IPoolManager(_positionManager);
        router = UniversalRouter(_router);
        _me = address(this);
    }
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
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

    function _afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) internal pure override returns (bytes4, int128) {
        require(
            key.currency0 == Currency.wrap(address(0)) &&
                key.currency1 == Currency.wrap(address(0)),
            "!poolId"
        );

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

        {
            PoolKey memory poolKey = PoolKey({
                currency0: Currency.wrap(address(_tokenBase)),
                currency1: Currency.wrap(address(_tokenQuote)),
                fee: 20_000,
                tickSpacing: 500,
                hooks: IHooks(address(0))
            });
            int24 tick = positionManager.initializePool(poolKey, sqrtPriceX96Launch);
            require(tick != type(int24).max, "!pool");

            launchParams[_tokenBase] = LaunchTokenParams({
                pool: pool,
                poolKey: poolKey,
                tick0: _tick0,
                tick1: _tick1,
                tick2: _tick2
            });
            require(address(_tokenBase) == poolKey.currency0.unwrap(), "!token0");
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

        // Creating liquidity involves using Uniswap V4 periphery contracts. It is not recommended to directly provide liquidity with poolManager.modifyPosition
        // Define the sequence of operations:
        // 1. MINT_POSITION - Creates the position and calculates token requirements
        // 2. SETTLE_PAIR - Provides the tokens needed
        bytes memory actions = abi.encodePacked(
            Actions.MINT_POSITION,
            Actions.MINT_POSITION,
            Actions.SETTLE_PAIR
        );
        bytes[] memory params = new bytes[](3);

        // Parameters for MINT_POSITION - specify tick0 to tick1
        params[0] = abi.encode(
            poolKey, // Which pool to mint in
            _tick0, // Position's lower price bound
            _tick1, // Position's upper price bound
            liquidityBeforeTick0, // Amount of liquidity to mint
            type(uint256).max, // Maximum amount of token0 to use
            type(uint256).max, // Maximum amount of token1 to use
            _me, // Who receives the NFT
            "" // No hook data needed
        );

        // Parameters for MINT_POSITION - specify tick1 to tick2
        params[1] = abi.encode(
            poolKey,
            _tick1,
            _tick2,
            liquidityBeforeTick1,
            type(uint256).max,
            type(uint256).max,
            _me,
            ""
        );

        // Parameters for SETTLE_PAIR - specify tokens to provide
        params[2] = abi.encode(
            poolKey.currency0, // First token to settle
            poolKey.currency1 // Second token to settle
        );

        positionManager.modifyLiquidities(
            abi.encode(actions, params),
            block.timestamp + 60 // 60 second deadline
        );
    }

    // @inheritdoc ICLMMAdapter
    function claimFees(
        address _token
    ) external returns (uint256 fee0, uint256 fee1) {
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

    // @inheritdoc ICLMMAdapter
    function swapForExactInput(
        IERC20 _tokenIn,
        IERC20 _tokenOut,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) external returns (uint256 amountOut) {
        PoolKey memory key = launchParams[_tokenIn].poolKey;
        require(
            key.currency0 == Currency.wrap(address(_tokenIn)) &&
                key.currency1 == Currency.wrap(address(_tokenOut)),
            "!poolId"
        );

        // Transfer the input token from the sender to this contract and approve the router
        _tokenIn.safeTransferFrom(msg.sender, address(this), _amountIn);
        _tokenIn.approve(address(router), type(uint256).max);

        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
                amountIn: _amountIn,
                amountOutMinimum: _minAmountOut,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(key.currency0, _amountIn);
        params[2] = abi.encode(key.currency1, _minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap
        router.execute(commands, inputs, deadline);

        // Verify and return the output amount
        amountOut = IERC20(key.currency1).balanceOf(address(this));
        require(amountOut >= _minAmountOut, "Insufficient output amount");
    }

    // @inheritdoc ICLMMAdapter
    function swapForExactOutput(
        IERC20 _tokenIn,
        IERC20 _tokenOut,
        uint256 _amountOut,
        uint256 _maxAmountIn
    ) external returns (uint256 amountIn) {
        PoolKey memory key = launchParams[_tokenIn].poolKey;
        require(
            key.currency0 == Currency.wrap(address(_tokenIn)) &&
                key.currency1 == Currency.wrap(address(_tokenOut)),
            "!poolId"
        );

        // Transfer the input token from the sender to this contract and approve the router
        _tokenIn.safeTransferFrom(msg.sender, address(this), _maxAmountIn);
        _tokenIn.approve(address(router), type(uint256).max);

        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_OUT_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactOutputSingleParams({
                poolKey: key,
                zeroForOne: true,
                amountOut: _amountOut,
                amountInMaximum: _maxAmountIn,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(key.currency0, _maxAmountIn);
        params[2] = abi.encode(key.currency1, _amountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap
        router.execute(commands, inputs, deadline);

        // Verify and return the input amount
        amountIn = IERC20(key.currency0).balanceOf(address(this));
        require(amountIn <= _maxAmountIn, "Too much input amount");
    }

    // @inheritdoc ICLMMAdapter
    function graduated(address token) external view returns (bool) {
        LaunchTokenParams memory params = launchParams[IERC20(token)];
        if (params.poolKey.fee == 0) return false;
        (, int24 tick, , , , , ) = params.pool.slot0();
        return tick >= params.tick1;
    }

}
