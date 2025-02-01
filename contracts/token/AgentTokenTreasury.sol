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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract AgentTokenTreasury is AgentTokenTimelock {
  using EnumerableSet for EnumerableSet.AddressSet;

  function addAsset(
    address asset
  ) external {
    require(msg.sender == address(this), "!timelock");
    assets.add(asset);
  }

  function removeAsset(
    address asset
  ) external {
    require(msg.sender == address(this), "!timelock");
    assets.remove(asset);
  }

  function claim(
    uint256 amount
  ) external {
    require(block.timestamp > expiry, "!expiry");
    _burn(msg.sender, amount);
    uint256 shares18 = 1 ether * amount / totalSupply();

    for (uint256 index = 0; index < assets.length(); index++) {
      IERC20 asset = IERC20(assets.at(index));
      if (asset == IERC20(address(this))) continue;
      uint256 total = asset.balanceOf(address(this));
      uint256 toSend = total * shares18 / 1 ether;
      asset.transfer(msg.sender, toSend);
    }
  }
}
