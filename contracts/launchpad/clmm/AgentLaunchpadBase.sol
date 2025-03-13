// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝    ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from
  "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPoolFactory} from "contracts/aerodrome/interfaces/IPoolFactory.sol";
import {IAgentLaunchpad} from "contracts/interfaces/IAgentLaunchpad.sol";
import {IAgentToken} from "contracts/interfaces/IAgentToken.sol";
import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";

abstract contract AgentLaunchpadBase is IAgentLaunchpad, OwnableUpgradeable, ERC721EnumerableUpgradeable {
  address public odos;

  address public tokenImplementation;
  IERC20[] public tokens;
  mapping(address => bool) public whitelisted;
  uint256 public creationFee;
  uint256 public maxDuration;
  uint256 public minDuration;
  uint256 public minFundingGoal;

  address public governor;
  address public checker;

  // fee details
  address public feeDestination;
  uint256 public feeCutE18;

  // funding details
  ICLMMAdapter public adapter;
  IERC20 public coreToken;
  IHooks public hook;
  IPoolManager public poolManager;
  mapping(address token => IAgentLaunchpad.LiquidityLock) public liquidityLocks;

  mapping(IAgentToken token => uint256) public fundingGoals;
  mapping(IAgentToken token => uint256) public tokensToSell;
  mapping(IAgentToken token => uint256) public lastTradedPrice;
  mapping(IAgentToken token => uint256) public fundingProgress;
  mapping(IAgentToken token => IERC20) public fundingTokens;
  mapping(IAgentToken token => uint256) public tokenToNftId;
  mapping(IAgentToken token => address) public graduatedToPool;

  receive() external payable {}
}
