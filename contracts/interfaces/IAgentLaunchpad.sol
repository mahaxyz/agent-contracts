// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {IPool} from "../aerodrome/interfaces/IPool.sol";
import {IPoolFactory} from "../aerodrome/interfaces/IPoolFactory.sol";
import {IAgentToken} from "./IAgentToken.sol";
import {IBondingCurve} from "./IBondingCurve.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAgentLaunchpad {
  event TokenCreated(
    address indexed token,
    address indexed creator,
    string name,
    string symbol,
    uint256 limitPerWallet,
    uint256 goal,
    uint256 duration,
    string metadata,
    address bondingCurve,
    bytes32 salt
  );

  struct CreateParamsBase {
    string name;
    string symbol;
    string metadata;
    IERC20 fundingToken;
    uint24 fee;
    uint256 limitPerWallet;
    bytes32 salt;
  }

  struct CreateParamsLiquidity {
    uint256 amountBaseBeforeTick;
    uint256 amountBaseAfterTick;
    uint160 initialSqrtPrice;
    int24 lowerTick;
    int24 upperTick;
    int24 upperMaxTick;
  }

  struct CreateParams {
    CreateParamsBase base;
    CreateParamsLiquidity liquidity;
  }

  // 0, // uint256 _amountBaseBeforeTick,
  // 0, // uint256 _amountBaseAfterTick,
  // 0, // uint24 _fee,
  // 0, // uint160 _sqrtPriceX96,
  // 0, // int24 _tick0,
  // 0, // int24 _tick1,
  // 0 // int24 _tick2

  struct LiquidityLock {
    IPool liquidityToken;
    uint256 amount;
  }

  event LiquidityLocked(address indexed token, address indexed pool, uint256 amount);
  event TokensPurchased(
    address indexed token,
    address indexed quoteToken,
    address indexed buyer,
    address destination,
    uint256 assetsIn,
    uint256 tokensOut,
    uint256 price
  );
  event TokensSold(
    address indexed token,
    address indexed quoteToken,
    address indexed seller,
    address destination,
    uint256 assetsOut,
    uint256 tokensIn,
    uint256 price
  );
  event SettingsUpdated(
    uint256 creationFee,
    uint256 maxDuration,
    uint256 minDuration,
    uint256 minFundingGoal,
    address feeDestination,
    uint256 feeCutE18
  );
  event TokenGraduated(address indexed token, uint256 assetsRaised);
}
