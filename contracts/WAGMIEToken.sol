// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Telegram: https://t.me/mahaxyz
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {ERC20BurnableUpgradeable} from
  "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";
import {ITokenTemplate} from "contracts/interfaces/ITokenTemplate.sol";

/// @title WAGMIEToken
/// @notice A contract for creating and managing tokens with presale functionality
contract WAGMIEToken is ITokenTemplate, ERC20BurnableUpgradeable {
  /// @notice The metadata of the token
  string public metadata;

  /// @notice The adapter contract
  ICLMMAdapter public adapter;

  /// @dev counts the number of transactions to claim fees
  uint256 private txCount;

  /// @inheritdoc ITokenTemplate
  function initialize(InitParams memory p) public initializer {
    metadata = p.metadata;
    adapter = ICLMMAdapter(p.adapter);

    __ERC20_init(p.name, p.symbol);

    _mint(msg.sender, 1_000_000_000 * 1e18); // 1 bn supply
  }

  function _update(address _from, address _to, uint256 _value) internal override {
    super._update(_from, _to, _value);
    // automatically claim fees every 100 transactions
    if (++txCount % 100 == 0) adapter.claimFees(address(this));
  }
}
