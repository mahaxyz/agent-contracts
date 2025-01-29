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

import {IERC20, AgentTokenBase} from "./AgentTokenBase.sol";

abstract contract AgentTokenPresale is AgentTokenBase {
    function presaleSwap(uint256 amount, bool buy) external {
        require(block.timestamp < expiry, "!expiry");
        require(approvedAssets[msg.sender], "!approved");

        if (buy) _mint(msg.sender, amount);
        else _burn(msg.sender, amount);

        // if funding goal has been met, automatically graduate the token
        if (checkFundingGoalMet()) graduate();
    }

    function graduate() public {
        uint256 raised = fundingToken.balanceOf(address(this));
        require(checkFundingGoalMet(), "!fundingGoal");

        // unlock the token for trading
        unlocked = true;

        // 25% of the TOKEN is already sold in the bonding curve
        require(balanceOf(address(this)) == 75 * totalSupply() / 100, "!balance");

        // send 15% of the TOKEN and 20% of the raised amount to LP
        _addLiquidity(15 * totalSupply() / 100, raised / 5);

        // keep 80% of the raise and lock 60% of the TOKEN to the treasury
        _lockTokens(3 * totalSupply() / 5);
        require(fundingToken.balanceOf(address(this)) >= 4 * raised / 5, "!balance");
    }

    function checkFundingGoalMet() public view returns (bool) {
        return fundingToken.balanceOf(address(this)) >= fundingGoal;
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
}
