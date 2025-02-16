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

import {IAeroPool} from "../interfaces/IAeroPool.sol";
import {IAgentToken, IERC20} from "../interfaces/IAgentToken.sol";
import {IBondingCurve} from "../interfaces/IBondingCurve.sol";
import {AgentLaunchpadLocker} from "./AgentLaunchpadLocker.sol";

abstract contract AgentLaunchpadSale is AgentLaunchpadLocker {
  function presaleSwap(
    IAgentToken token,
    address destination,
    uint256 tokensToBuyOrSell,
    uint256 minAmountOut,
    bool buy
  ) external {
    _presaleSwap(token, destination, tokensToBuyOrSell, minAmountOut, buy);
  }

  function presaleSwapWithOdos(
    IAgentToken token,
    address destination,
    uint256 tokensToBuyOrSell,
    uint256 minAmountOut,
    bool buy,
    IERC20 inputToken,
    uint256 inputAmount,
    bytes memory data
  ) external payable {
    if (inputToken != IERC20(address(0))) {
      inputToken.transferFrom(msg.sender, address(this), inputAmount);
      inputToken.approve(odos, inputAmount);
    }

    if (buy) {
      // swap for QUOTE and then swap for TOKEN
      (bool success,) = odos.call{value: inputAmount}(data);
      require(success, "odos call failed");
      _presaleSwap(token, destination, tokensToBuyOrSell, minAmountOut, true);
    } else {
      // swap for TOKEN and then swap for QUOTE
      _presaleSwap(token, destination, tokensToBuyOrSell, minAmountOut, false);
      (bool success,) = odos.call(data);
      require(success, "odos call failed");
    }
  }

  function graduate(IAgentToken token) public {
    IERC20 fundingToken = IERC20(fundingTokens[token]);
    uint256 raised = fundingToken.balanceOf(address(this));
    require(!token.unlocked(), "presale is over");
    require(checkFundingGoalMet(token), "!fundingGoal");

    // unlock the token for trading
    token.unlock();

    // X% of the TOKEN is already sold in the bonding curve and in the hands of users

    // send rest of the TOKEN and 100% of the raised amount to LP
    _addLiquidity(token, fundingToken, token.totalSupply() - 3 * token.totalSupply() / 20, raised);

    // keep 80% of the raise and lock 60% of the TOKEN to the treasury
    fundingToken.transfer(address(token), 4 * raised / 5);

    emit TokenGraduated(address(token), raised);
  }

  function checkFundingGoalMet(IAgentToken token) public view returns (bool) {
    return fundingProgress[token] >= fundingGoals[token];
  }

  function _presaleSwap(
    IAgentToken token,
    address destination,
    uint256 tokensToBuyOrSell,
    uint256 minAmountOut,
    bool buy
  ) internal {
    require(!token.unlocked(), "presale is over");
    IERC20 fundingToken = IERC20(fundingTokens[token]);
    uint256 price;
    uint256 _assetsOrTokensIn;
    uint256 _tokensOrAssetsOut;

    IBondingCurve.DataBuy memory dataBuy;
    IBondingCurve.DataSell memory dataSell;

    {
      dataBuy = IBondingCurve.DataBuy({
        tokensToBuyAfterFees: tokensToBuyOrSell * (9970) / 10_000,
        fundingProgress: fundingProgress[token],
        fundingGoals: fundingGoals[token],
        tokensToSell: tokensToSell[token]
      });

      dataSell = IBondingCurve.DataSell({
        quantityOut: tokensToBuyOrSell,
        raisedAmount: fundingProgress[token],
        totalRaise: fundingGoals[token],
        targetTokensToSell: tokensToSell[token]
      });
    }

    if (buy) {
      // take fees
      uint256 tokensToBuyAfterFees = tokensToBuyOrSell * (9970) / 10_000;
      uint256 fee = tokensToBuyOrSell - tokensToBuyAfterFees;
      fundingToken.transferFrom(msg.sender, feeDestination, fee);

      // calculate the amount of tokens to give
      (_tokensOrAssetsOut, _assetsOrTokensIn, price) = curves[token].calculateBuy(dataBuy);
      fundingProgress[token] += _assetsOrTokensIn;

      // settle the trade
      fundingToken.transferFrom(msg.sender, address(this), _assetsOrTokensIn);
      token.transfer(destination, _tokensOrAssetsOut);
      require(_tokensOrAssetsOut >= minAmountOut, "!minAmountOut");

      emit TokensPurchased(
        address(token), address(fundingToken), msg.sender, destination, _assetsOrTokensIn, _tokensOrAssetsOut, price
      );
    } else {
      // calculate the amount of tokens to take
      (_tokensOrAssetsOut, _assetsOrTokensIn, price) = curves[token].calculateSell(dataSell);
      fundingProgress[token] -= _tokensOrAssetsOut;

      // take fees
      uint256 assetsOutAfterFee = _tokensOrAssetsOut * (9970) / 10_000;
      uint256 fee = _tokensOrAssetsOut - assetsOutAfterFee;
      fundingToken.transfer(feeDestination, fee);

      // settle the trade
      fundingToken.transfer(destination, assetsOutAfterFee);
      token.transferFrom(msg.sender, address(this), _assetsOrTokensIn);
      require(assetsOutAfterFee >= minAmountOut, "!minAmountOut");

      emit TokensSold(
        address(token), address(fundingToken), msg.sender, destination, _tokensOrAssetsOut, _assetsOrTokensIn, price
      );
    }

    lastTradedPrice[token] = price;

    // if funding goal has been met, automatically graduate the token
    if (checkFundingGoalMet(token)) graduate(token);
  }

  function _addLiquidity(IAgentToken token, IERC20 fundingToken, uint256 amountToken, uint256 amountETH) internal {
    address pool = aeroFactory.getPool(address(token), address(fundingToken), false);
    if (pool == address(0)) {
      pool = aeroFactory.createPool(address(token), address(fundingToken), false);
    }

    token.transfer(pool, amountToken);
    fundingToken.transfer(pool, amountETH);

    IAeroPool(pool).mint(address(this));
    _lockLiquidity(token, pool);
    // todo add event
  }
}
