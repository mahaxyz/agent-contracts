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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IStakeRewardsStrategy} from "contracts/interfaces/IStakeRewardsStrategy.sol";

/// @title IAMMStake Interface
/// @notice Interface for managing token staking with lock periods and rewards distribution
/// @dev Implements IERC721Receiver for potential NFT-related functionality
interface IAMMStake is IERC721Receiver {
  event LockDurationSet(address indexed owner, IERC20 indexed token, uint256 lockDuration);
  event LockAmountSet(address indexed owner, IERC20 indexed token, uint256 amount);
  event Staked(address indexed owner, IERC20 indexed token, uint256 amount);
  event Unstaked(address indexed owner, IERC20 indexed token);
  event RewardsStrategySet(
    address indexed owner,
    IERC20 indexed token,
    IStakeRewardsStrategy rewardsStrategy,
    IStakeRewardsStrategy.RewardsConfigData config
  );
  event RewardsDistributed(address indexed owner, IERC20 indexed token);

  /// @notice Get the lock duration for a specific owner and token
  /// @param _owner The address of the owner
  /// @param _token The ERC20 token address
  /// @return The lock duration in seconds
  function getLockDuration(address _owner, IERC20 _token) external view returns (uint256);

  /// @notice Get the locked amount for a specific owner and token
  /// @param _owner The address of the owner
  /// @param _token The ERC20 token address
  /// @return The locked amount of tokens
  function getLockAmount(address _owner, IERC20 _token) external view returns (uint256);

  /// @notice Stake tokens with a specified lock duration
  /// @param _token The ERC20 token to stake
  /// @param _amount The amount of tokens to stake
  /// @param _lockDuration The duration to lock the tokens for
  function stake(IERC20 _token, uint256 _amount, uint256 _lockDuration) external;

  /// @notice Unstake tokens for a specific owner
  /// @param _owner The address of the owner
  /// @param _token The ERC20 token to unstake
  function unstake(address _owner, IERC20 _token) external;

  /// @notice Set the rewards strategy for a specific owner and token
  /// @param _owner The address of the owner
  /// @param _token The ERC20 token address
  /// @param _rewardsStrategy The address of the rewards strategy contract
  /// @param _config The rewards configuration data
  function setRewardsStrategy(
    address _owner,
    IERC20 _token,
    IStakeRewardsStrategy _rewardsStrategy,
    IStakeRewardsStrategy.RewardsConfigData calldata _config
  ) external;

  /// @notice Distribute rewards for a specific owner and token
  /// @param _owner The address of the owner
  /// @param _token The ERC20 token address
  function distributeRewards(address _owner, IERC20 _token) external;
}
