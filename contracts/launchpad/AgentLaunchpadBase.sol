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

import {IAeroPoolFactory} from "../interfaces/IAeroPoolFactory.sol";
import {IAgentLaunchpad} from "../interfaces/IAgentLaunchpad.sol";
import {IAgentToken} from "../interfaces/IAgentToken.sol";
import {IBondingCurve} from "../interfaces/IBondingCurve.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ERC721EnumerableUpgradeable} from
  "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract AgentLaunchpadBase is IAgentLaunchpad, OwnableUpgradeable, ERC721EnumerableUpgradeable {
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
  IAeroPoolFactory public aeroFactory;
  IERC20 public coreToken;
  mapping(address token => IAgentLaunchpad.LiquidityLock) public liquidityLocks;
  mapping(address token => IAgentLaunchpad.TokenLock) public tokenLocks;
  mapping(IAgentToken token => IBondingCurve) public curves;
  mapping(IAgentToken token => uint256) public fundingGoals;
  mapping(IAgentToken token => uint256) public fundingProgress;
  mapping(IAgentToken token => IERC20) public fundingTokens;
  mapping(IAgentToken token => uint256) public tokenToNftId;
}
