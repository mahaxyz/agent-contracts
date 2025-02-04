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

import {AgentTokenTreasury} from "./AgentTokenTreasury.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20, ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

abstract contract AgentTokenPresale is AgentTokenTreasury {
  function unlock() external {
    require(msg.sender == launchpad, "!launchpad");
    unlocked = true;
    emit Unlocked();
  }

  function extendExpiry(uint256 _expiry) external onlyRole(GOVERNANCE) {
    require(_expiry > expiry, "!_expiry");
    expiry = _expiry;
    emit ExpiryExtended(_expiry);
  }
}
