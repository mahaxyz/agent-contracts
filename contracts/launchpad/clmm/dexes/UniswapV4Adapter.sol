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
import {ITokenTemplate} from "contracts/interfaces/ITokenTemplate.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {ICLMMAdapter, IERC20} from "contracts/interfaces/ICLMMAdapter.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {Commands} from "node_modules/@uniswap/universal-router/contracts/libraries/Commands.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniversalRouter} from "contracts/interfaces/thirdparty/uniswapv4/IUniversalRouter.sol";
import {IUniswapV4Adapter} from "contracts/interfaces/IUniswapV4Adapter.sol";
import { IPermit2 } from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {SqrtPriceMath} from "@uniswap/v4-core/src/libraries/SqrtPriceMath.sol";
contract UniswapV4Adapter is IUniswapV4Adapter, Initializable {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using SafeERC20 for IERC20;

    address public launchpad;
    mapping(IERC20 token => LaunchTokenParams params) public launchParams;
    address private _me;
    IUniversalRouter public router;
    IPositionManager public positionManager;
    IPoolManager public poolManager;
    address public WETH9;
    IPermit2 public permit2;
    function initialize(
        address _launchpad,
        address _positionManager,
        address _router,
        address _poolManager,
        address _permit2,
        address _WETH9
    ) external initializer {
        launchpad = _launchpad;
        positionManager = IPositionManager(_positionManager);
        router = IUniversalRouter(_router);
        poolManager = IPoolManager(_poolManager);
        permit2 = IPermit2(_permit2);
        _me = address(this);
        WETH9 = _WETH9;
    }

    function addSingleSidedLiquidity(
        IERC20 _tokenBase,
        IERC20 _tokenQuote,
        int24 _tick0,
        int24 _tick1,
        int24 _tick2
    ) external {
        require(msg.sender == launchpad, "!launchpad");
        require(launchParams[_tokenBase].poolKey.fee == 0, "!launched");
        uint160 sqrtPriceX96Launch = TickMath.getSqrtPriceAtTick(_tick0 - 1);
        uint160 sqrtPriceX960 = TickMath.getSqrtPriceAtTick(_tick0);
        uint160 sqrtPriceX961 = TickMath.getSqrtPriceAtTick(_tick1);
        uint160 sqrtPriceX962 = TickMath.getSqrtPriceAtTick(_tick2);

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(address(_tokenBase)),
            currency1: Currency.wrap(address(_tokenQuote)),
            fee: 20_000,
            tickSpacing: 500,
            hooks: IHooks(address(0))
        });
        int24 tick = positionManager.initializePool(
            poolKey,
            sqrtPriceX96Launch
        );
        require(tick != type(int24).max, "!uniswapV4Adapter: pool not initialized");

        launchParams[_tokenBase] = LaunchTokenParams({
            poolKey: poolKey,
            tick0: _tick0,
            tick1: _tick1,
            tick2: _tick2
        });
        require(
            address(_tokenBase) == Currency.unwrap(poolKey.currency0),
            "!token0"
        );
        ITokenTemplate(address(_tokenBase)).whitelist(address(positionManager));

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

        
        uint256 amt0 = SqrtPriceMath.getAmount0Delta(sqrtPriceX960, sqrtPriceX961, liquidityBeforeTick0, true);
        uint256 amt1 = SqrtPriceMath.getAmount0Delta(sqrtPriceX961, sqrtPriceX962, liquidityBeforeTick1, true);
        IERC20(_tokenBase).safeTransferFrom(msg.sender, address(this), amt0+amt1);

        // Creating liquidity involves using Uniswap V4 periphery contracts. It is not recommended to directly provide liquidity with poolManager.modifyPosition
        // Define the sequence of operations:
        // 1. MINT_POSITION - Creates the position and calculates token requirements
        // 2. SETTLE_PAIR - Provides the tokens needed
        bytes memory actions = new bytes(3);

        bytes1 action1 = bytes1(uint8(Actions.MINT_POSITION));
        bytes1 action2 = bytes1(uint8(Actions.MINT_POSITION));
        bytes1 action3 = bytes1(uint8(Actions.SETTLE_PAIR));

        actions[0] = action1;
        actions[1] = action2;
        actions[2] = action3;

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

        IERC20(Currency.unwrap(poolKey.currency0)).approve(address(permit2), type(uint256).max);
        permit2.approve(Currency.unwrap(poolKey.currency0), address(positionManager), type(uint160).max, type(uint48).max);
        
        positionManager.modifyLiquidities(
            abi.encode(actions, params),
            block.timestamp + 60 // 60 second deadline
        );
    }

    // @inheritdoc ICLMMAdapter
    // TODO: Implement this using positionManager
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
        _tokenIn.approve(address(permit2), type(uint256).max);
        permit2.approve(address(_tokenIn), address(router), type(uint160).max, type(uint48).max);
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
                amountIn: uint128(_amountIn),
                amountOutMinimum: uint128(_minAmountOut),
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(key.currency0, uint128(_amountIn));
        params[2] = abi.encode(key.currency1, uint128(_minAmountOut));

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap
        router.execute(commands, inputs, block.timestamp + 60);

        // Verify and return the output amount
        amountOut = _tokenOut.balanceOf(address(this));
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

        // Approve router to spend input token
        _tokenIn.approve(address(router), _maxAmountIn);

        // Prepare swap parameters
        V4SwapRouter.ExactOutputParams memory params = V4SwapRouter.ExactOutputParams({
            poolKey: key,
            recipient: msg.sender,
            amountOut: _amountOut,
            amountInMaximum: _maxAmountIn,
            sqrtPriceLimitX96: 0,
            tickLimit: 0,
            hookData: ""
        });

        // Execute the swap
        amountIn = router.exactOutput(params);

        // Revoke approval
        _tokenIn.approve(address(router), 0);
    }

    // @inheritdoc ICLMMAdapter
    function graduated(address token) external view returns (bool) {
        LaunchTokenParams memory params = launchParams[IERC20(token)];
        if (params.poolKey.fee == 0) return false;
        (, int24 tick, , ) = poolManager.getSlot0(params.poolKey.toId());
        return tick >= params.tick1;
    }

    function getPool(IERC20 _token) external view returns (PoolKey memory poolKey) {
        poolKey = launchParams[_token].poolKey;
    }
    function launchedTokens(
        IERC20 _token
    ) external view returns (bool launched) {
        launched = launchParams[_token].poolKey.fee != 0;
    }
    
    /// @notice Collects accumulated fees from a position
    /// @param tokenId The ID of the position to collect fees from
    /// @param recipient Address that will receive the fees
    function collectFees(
        uint256 tokenId,
        address recipient
    ) external {
        require(msg.sender == launchpad, "!launchpad");
        LaunchTokenParams memory params = launchParams[IERC20(_token)];
        // Define the sequence of operations
        bytes memory actions = abi.encodePacked(
            Actions.DECREASE_LIQUIDITY, // Remove liquidity
            Actions.TAKE_PAIR           // Receive both tokens
        );

        // Prepare parameters array
        bytes[] memory params = new bytes[](2);

        // Parameters for DECREASE_LIQUIDITY
        // All zeros since we're only collecting fees
        params[0] = abi.encode(
            tokenId,    // Position to collect from
            0,          // No liquidity change
            0,          // No minimum for token0 (fees can't be manipulated)
            0,          // No minimum for token1
            ""          // No hook data needed
        );

        // Standard TAKE_PAIR for receiving all fees
        params[1] = abi.encode(
            params.poolKey.currency0,
            params.poolKey.currency1,
            recipient
        );
        // Execute fee collection
        positionManager.modifyLiquidities(
            abi.encode(actions, params),
            block.timestamp + 60  // 60 second deadline
        );
    }
}