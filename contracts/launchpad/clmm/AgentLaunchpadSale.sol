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

import {AgentLaunchpadLocker} from "./AgentLaunchpadLocker.sol";
import {IPool} from "contracts/aerodrome/interfaces/IPool.sol";
import {IAgentToken, IERC20} from "contracts/interfaces/IAgentToken.sol";
import {IBondingCurve} from "contracts/interfaces/IBondingCurve.sol";

abstract contract AgentLaunchpadSale is AgentLaunchpadLocker {
  function graduate(IAgentToken token) public {
    IERC20 fundingToken = IERC20(fundingTokens[token]);
    uint256 raised = fundingToken.balanceOf(address(this));
    require(!token.unlocked(), "presale is over");
    require(checkFundingGoalMet(token), "!fundingGoal");

    // unlock the token for trading
    token.unlock();

    // X% of the TOKEN is already sold in the bonding curve and in the hands of users

    // send rest of the TOKEN and 100% of the raised amount to LP
    uint256 tokensToAdd = token.balanceOf(address(this));
    _addLiquidity(token, fundingToken, tokensToAdd, raised);

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

    IPool(pool).mint(address(this));
    _lockLiquidity(token, pool);

    graduatedToPool[token] = pool;
  }
}
