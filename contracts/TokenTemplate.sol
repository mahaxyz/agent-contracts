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

import {ERC20BurnableUpgradeable} from
  "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";
import {ITokenTemplate} from "contracts/interfaces/ITokenTemplate.sol";

/// @title TokenTemplate
/// @notice A contract for creating and managing tokens with presale functionality
contract TokenTemplate is ITokenTemplate, ERC20BurnableUpgradeable {
  /// @notice The metadata of the token
  string public metadata;

  /// @notice Whether the token is unlocked for transfers
  bool public unlocked;

  /// @notice The limit of tokens per wallet before the token is graduated
  uint256 public limitPerWallet;

  /// @notice The whitelist of addresses that can transfer tokens before the token is graduated
  mapping(address => bool) public whitelisted;

  /// @notice The adapter contract
  ICLMMAdapter public adapter;

  /// @dev counts the number of transactions to claim fees
  uint256 private txCount;

  /// @inheritdoc ITokenTemplate
  function initialize(InitParams memory p) public initializer {
    limitPerWallet = p.limitPerWallet;
    metadata = p.metadata;
    unlocked = false;
    adapter = ICLMMAdapter(p.adapter);

    __ERC20_init(p.name, p.symbol);

    whitelisted[msg.sender] = true;
    whitelisted[address(adapter)] = true;
    whitelisted[address(0)] = true;
    _mint(msg.sender, 1_000_000_000 * 1e18); // 1 bn supply
  }

  function _update(address _from, address _to, uint256 _value) internal override {
    super._update(_from, _to, _value);
    if (!unlocked) {
      if (adapter.graduated(address(this))) {
        // if the token is graduated, then allow transfers
        unlocked = true;
        emit Unlocked();
        return;
      } else if (!whitelisted[_from]) {
        // buy tokens; limit to `limitPerWallet` per wallet
        require(balanceOf(_to) <= limitPerWallet, "!limitPerWallet from");
      } else if (whitelisted[_to]) {
        // sell tokens; allow without limits
      }
    }

    // automatically claim fees every 100 transactions
    if (++txCount % 100 == 0) adapter.claimFees(address(this));
  }

  /// @inheritdoc ITokenTemplate
  function whitelist(address _address) external {
    require(msg.sender == address(adapter), "!whitelist");
    whitelisted[_address] = true;
    emit Whitelisted(_address);
  }

  /// @inheritdoc ITokenTemplate
  function isWhitelisted(address _address) external view override returns (bool) {
    return whitelisted[_address];
  }
}
