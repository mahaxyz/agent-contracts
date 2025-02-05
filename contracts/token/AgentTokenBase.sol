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
import {IBondingCurve} from "../interfaces/IBondingCurve.sol";
import {ILocker} from "../interfaces/ILocker.sol";
import {ITxChecker} from "../interfaces/ITxChecker.sol";
import {AccessControlEnumerableUpgradeable} from
  "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

import {
  ERC20BurnableUpgradeable,
  ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

import {ERC20VotesUpgradeable} from
  "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract AgentTokenBase is
  IAgentToken,
  ERC20VotesUpgradeable,
  ERC20BurnableUpgradeable,
  AccessControlEnumerableUpgradeable
{
  // basic info
  string public metadata;
  bool public unlocked;
  address public launchpad;
  uint256 public limitPerWallet;

  // roles
  bytes32 public FUND_MANAGER = keccak256("FUND_MANAGER");
  bytes32 public GOVERNANCE = keccak256("GOVERNANCE");

  // treasury variables
  uint256 public expiry;
  EnumerableSet.AddressSet internal assets;

  // timelock variables
  struct Transaction {
    address to;
    uint256 value;
    uint256 executeAt;
    uint256 nonce;
    bool executed;
    bool cancelled;
    bytes data;
  }

  ITxChecker public txChecker;
  mapping(bytes32 => Transaction) public hashToTransactions;
  Transaction[] public transactions;
  uint256 internal lastExecutedNonce;
  uint256 internal lastProposedNonce;
  uint256 public minDelay;

  receive() external payable {
    // accepts eth into this contract
  }

  function _update(address _from, address _to, uint256 _value)
    internal
    override (ERC20Upgradeable, ERC20VotesUpgradeable)
  {
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
      require(_to == address(0), "fund expired");
    }
  }
}
