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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AgentTokenTreasury} from "./AgentTokenTreasury.sol";

abstract contract AgentTokenPresale is AgentTokenTreasury {
    function presaleSwap(uint256 amountIn, uint256 minAmountOut, bool buy) external {
        require(!unlocked, "presale is over");

        if (buy) {
            (uint256 amountGiven, uint256 amountTaken) = curve.calculateOut(amountIn, fundingProgress, fundingGoal);
            fundingProgress += amountTaken;
            raiseToken.transferFrom(msg.sender, address(this), amountTaken);
            _transfer(address(this), msg.sender, amountGiven);
            require(amountGiven >= minAmountOut, "!minAmountOut");
        } else {
            (uint256 amountGiven, uint256 amountTaken) = curve.calculateIn(amountIn, fundingProgress, fundingGoal);
            fundingProgress -= amountGiven;
            raiseToken.transfer(msg.sender, address(this), amountGiven);
            _transfer(msg.sender, address(this), amountTaken);
            require(amountGiven >= minAmountOut, "!minAmountOut");
        }

        // if funding goal has been met, automatically graduate the token
        if (checkFundingGoalMet()) graduate();
    }

    function graduate() public {
        uint256 raised = fundingToken.balanceOf(address(this));
        require(!unlocked, "presale is over");
        require(checkFundingGoalMet(), "!fundingGoal");

        // unlock the token for trading
        unlocked = true;

        // 25% of the TOKEN is already sold in the bonding curve and in the hands of users

        // send 15% of the TOKEN and 20% of the raised amount to LP
        _addLiquidity(15 * totalSupply() / 100, raised / 5);

        // keep 80% of the raise and lock 60% of the TOKEN to the treasury
        _lockTokens(3 * totalSupply() / 5);
        require(fundingToken.balanceOf(address(this)) >= 4 * raised / 5, "!balance");
    }

    function checkFundingGoalMet() public view returns (bool) {
        return fundingProgress >= fundingGoal;
    }

    function _addLiquidity(uint256 amountToken, uint256 amountETH) internal {
        address pool = aeroFactory.getPool(address(this), address(fundingToken), 1000);
        if (pool == address(0)) {
            aeroFactory.createPool(address(fundingToken), address(fundingToken), 1000, 0);
        }

        _approve(address(this), address(aeroFactory), amountToken);
        // aeroFactory.addLiquidity(
        //     address(this), address(fundingToken), amountToken, amountETH, 0, 0, address(0), block.timestamp
        // );
        locker.lockNFT(address(0), 0, expiry - block.timestamp);
    }

    function _lockTokens(uint256 amount) internal {
        _approve(address(this), address(locker), amount);
        locker.lockTokens(address(this), amount, expiry - block.timestamp);
    }

    function _update(address _from, address _to, uint256 _value) internal override {
        super._update(_from, _to, _value);
        if (!unlocked) {
            if (_from == address(this)) {
                // buy tokens; limit to 3% of the supply per wallet
                require(balanceOf(_to) <= limitPerWallet, "!limitPerWallet");
            } else if (_to == address(this)) {
                // sell tokens; allow without limits
            } else {
                // disallow transfers between users until the presale is over
                require(false, "!transfer");
            }
        }
    }
}
