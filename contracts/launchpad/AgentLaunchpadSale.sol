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
import {IAgentToken} from "../interfaces/IAgentToken.sol";
import {IBondingCurve} from "../interfaces/IBondingCurve.sol";
import {AgentLaunchpadLocker} from "./AgentLaunchpadLocker.sol";

abstract contract AgentLaunchpadSale is AgentLaunchpadLocker {
    function presaleSwap(IAgentToken token, uint256 amountIn, uint256 minAmountOut, bool buy) external {
        require(!token.unlocked(), "presale is over");

        if (buy) {
            (uint256 amountGiven, uint256 amountTaken) =
                curves[token].calculateBuy(amountIn, fundingProgress[token], fundingGoals[token]);
            fundingProgress[token] += amountTaken;
            fundingToken.transferFrom(msg.sender, address(this), amountTaken);
            token.transfer(msg.sender, amountGiven);
            require(amountGiven >= minAmountOut, "!minAmountOut");

            emit TokensPurchased(token, msg.sender, amountTaken, amountGiven);
        } else {
            (uint256 amountGiven, uint256 amountTaken) =
                curves[token].calculateSell(amountIn, fundingProgress[token], fundingGoals[token]);
            fundingProgress[token] -= amountGiven;
            fundingToken.transfer(msg.sender, amountGiven);
            token.transferFrom(msg.sender, address(this), amountTaken);
            require(amountGiven >= minAmountOut, "!minAmountOut");

            emit TokensSold(token, msg.sender, amountTaken, amountGiven);
        }

        // if funding goal has been met, automatically graduate the token
        if (checkFundingGoalMet(token)) graduate(token);
    }

    function graduate(IAgentToken token) public {
        uint256 raised = fundingToken.balanceOf(address(this));
        require(!token.unlocked(), "presale is over");
        require(checkFundingGoalMet(token), "!fundingGoal");

        // unlock the token for trading
        token.unlock();

        // 25% of the TOKEN is already sold in the bonding curve and in the hands of users

        // send 15% of the TOKEN and 20% of the raised amount to LP
        _addLiquidity(token, 3 * token.totalSupply() / 20, raised / 5);

        // keep 80% of the raise and lock 60% of the TOKEN to the treasury
        fundingToken.transfer(address(token), 4 * raised / 5);
        _lockTokens(token, 3 * token.totalSupply() / 5);
    }

    function checkFundingGoalMet(IAgentToken token) public view returns (bool) {
        return fundingProgress[token] >= fundingGoals[token];
    }

    function _addLiquidity(IAgentToken token, uint256 amountToken, uint256 amountETH) internal {
        address pool = aeroFactory.getPool(address(token), address(fundingToken), false);
        if (pool == address(0)) {
            aeroFactory.createPool(address(fundingToken), address(fundingToken), false);
        }

        token.transfer(pool, amountToken);
        fundingToken.transfer(pool, amountETH);

        IAeroPool(pool).mint(address(this));
        _lockLiquidity(token, pool);
    }
}
