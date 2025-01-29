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

import {AgentTokenTimelock} from "./AgentTokenTimelock.sol";

abstract contract AgentTokenTreasury is AgentTokenTimelock {
    function addAsset(address asset) external onlyRole(FUND_MANAGER) {
        assets.push(asset);
    }

    function removeAsset(address asset) external onlyRole(FUND_MANAGER) {
        assets.push(asset);
    }

    function claim(uint256 amount) external {
        // require(block.timestamp > expiry, "!expiry");

        // _burn(msg.sender, amount);
        // uint256 shares18 = 1 ether * amount / totalSupply();

        // for (uint256 index = 0; index < assets.length; index++) {
        //     IERC20 asset = IERC20(assets[index]);
        //     if (asset == IERC20(address(this))) continue;
        //     uint256 total = asset.balanceOf(address(this));
        //     uint256 toSend = total * shares18 / 1 ether;
        //     asset.transfer(msg.sender, toSend);
        // }
    }
}
