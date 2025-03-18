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

import {IAgentToken} from "../interfaces/IAgentToken.sol";

import {ICLMMAdapter} from "../interfaces/ICLMMAdapter.sol";
import {ERC20BurnableUpgradeable} from
  "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract AgentTokenBase is IAgentToken, ERC20BurnableUpgradeable {
  // basic info
  string public metadata;
  bool public unlocked;
  uint256 public limitPerWallet;
  mapping(address => bool) public whitelisted;
  ICLMMAdapter public adapter;

  receive() external payable {
    // accepts eth into this contract
  }

  function _update(address _from, address _to, uint256 _value) internal override {
    super._update(_from, _to, _value);
    // if (!unlocked) {
    //   if (adapter.graduated(address(this))) {
    //     // if the token is graduated, then allow transfers
    //     unlocked = true;
    //     emit Unlocked();
    //     return;
    //   } else if (whitelisted[_from]) {
    //     // buy tokens; limit to `limitPerWallet` per wallet
    //     require(balanceOf(_to) <= limitPerWallet, "!limitPerWallet");
    //   } else if (whitelisted[_to]) {
    //     // sell tokens; allow without limits
    //   } else {
    //     // disallow transfers between users until the presale is over
    //     require(false, "!transfer");
    //   }
    // }
  }

  function isWhitelisted(address _address) external view override returns (bool) {
    return whitelisted[_address];
  }
}
