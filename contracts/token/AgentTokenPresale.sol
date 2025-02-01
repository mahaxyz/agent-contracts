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

abstract contract AgentTokenPresale is AgentTokenTreasury {
  function unlock() external {
    require(msg.sender == launchpad, "!launchpad");
    unlocked = true;
    emit Unlocked();
  }

  function _update(address _from, address _to, uint256 _value) internal override {
    super._update(_from, _to, _value);
    if (!unlocked) {
      if (_from == address(launchpad)) {
        // buy tokens; limit to `limitPerWallet` per wallet
        require(balanceOf(_to) <= limitPerWallet, "!limitPerWallet");
      } else if (_to == address(launchpad)) {
        // sell tokens; allow without limits
      } else {
        // disallow transfers between users until the presale is over
        require(false, "!transfer");
      }
    }
    if (block.timestamp > expiry) {
      // disable transfers after the presale ends
    }
  }
}
