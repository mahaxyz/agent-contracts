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
  function presaleSwap(IAgentToken token, uint256 tokensToBuyOrSell, uint256 minAmountOut, bool buy) external {
    require(!token.unlocked(), "presale is over");
    IERC20 fundingToken = IERC20(fundingTokens[token]);

    if (buy) {
      // take fees
      uint256 tokensToBuyAfterFees = tokensToBuyOrSell * (9970) / 10_000;
      uint256 fee = tokensToBuyOrSell - tokensToBuyAfterFees;
      fundingToken.transferFrom(msg.sender, feeDestination, fee);

      // calculate the amount of tokens to give
      (uint256 _tokensOut, uint256 _assetsIn, uint256 price) =
        curves[token].calculateBuy(tokensToBuyAfterFees, fundingProgress[token], fundingGoals[token]);
      fundingProgress[token] += _assetsIn;

      // settle the trade
      fundingToken.transferFrom(msg.sender, address(this), _assetsIn);
      token.transfer(msg.sender, _tokensOut);
      require(_tokensOut >= minAmountOut, "!minAmountOut");

      emit TokensPurchased(address(token), msg.sender, _assetsIn, _tokensOut, price);
    } else {
      // calculate the amount of tokens to take
      (uint256 _assetsOut, uint256 _tokensIn, uint256 price) =
        curves[token].calculateSell(tokensToBuyOrSell, fundingProgress[token], fundingGoals[token]);
      fundingProgress[token] -= _assetsOut;

      // take fees
      uint256 assetsOutAfterFee = _assetsOut * (9970) / 10_000;
      uint256 fee = _assetsOut - assetsOutAfterFee;
      fundingToken.transfer(feeDestination, fee);

      // settle the trade
      fundingToken.transfer(msg.sender, assetsOutAfterFee);
      token.transferFrom(msg.sender, address(this), _tokensIn);
      require(assetsOutAfterFee >= minAmountOut, "!minAmountOut");

      emit TokensSold(address(token), msg.sender, _assetsOut, _tokensIn, price);
    }

    // if funding goal has been met, automatically graduate the token
    if (checkFundingGoalMet(token)) graduate(token);
  }

  function graduate(IAgentToken token) public {
    IERC20 fundingToken = IERC20(fundingTokens[token]);
    uint256 raised = fundingToken.balanceOf(address(this));
    require(!token.unlocked(), "presale is over");
    require(checkFundingGoalMet(token), "!fundingGoal");

    // unlock the token for trading
    token.unlock();

    // 25% of the TOKEN is already sold in the bonding curve and in the hands of users

    // send 15% of the TOKEN and 20% of the raised amount to LP
    _addLiquidity(token, fundingToken, 3 * token.totalSupply() / 20, raised / 5);

    // keep 80% of the raise and lock 60% of the TOKEN to the treasury
    fundingToken.transfer(address(token), 4 * raised / 5);
    _lockTokens(token, 3 * token.totalSupply() / 5);

    emit TokenGraduated(address(token), raised);
  }

  function checkFundingGoalMet(IAgentToken token) public view returns (bool) {
    return fundingProgress[token] >= fundingGoals[token];
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
