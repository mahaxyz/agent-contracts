// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝    ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://wagmie.com
// Telegram: https://t.me/mahaxyz
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ILaunchpool
/// @notice Interface for the Launchpool contract that allows users to stake tokens and receive rewards
interface ILaunchpool {
  /// @notice Struct containing reward drop information
  /// @param rewardToken Address of the reward token
  /// @param totalReward Total amount of tokens to distribute as rewards
  /// @param snapshotBlock Block number when the reward drop was created
  struct RewardDrop {
    IERC20 rewardToken;
    uint256 totalReward;
    uint32 snapshotBlock;
  }

  /// @notice Emitted when a new reward is funded
  /// @param rewardToken Address of the reward token
  /// @param amount Amount of tokens funded
  event RewardFunded(IERC20 indexed rewardToken, uint256 amount);

  /// @notice Emitted when a user withdraws staked tokens
  /// @param user Address of the user
  /// @param amount Amount withdrawn
  event Withdraw(address indexed user, uint256 amount);

  /// @notice Emitted when a user stakes tokens
  /// @param user Address of the user
  /// @param amount Amount staked
  event Stake(address indexed user, uint256 amount);

  /// @notice Emitted when a user claims rewards
  /// @param user Address of the user
  /// @param rewardToken Address of the reward token
  /// @param amount Amount of rewards claimed
  event RewardClaimed(address indexed user, IERC20 indexed rewardToken, uint256 amount);

  /// @notice Initializes the contract
  /// @param _stakingToken Address of the token that can be staked
  /// @param _launchpad Address of the launchpad contract
  function initialize(address _stakingToken, address _launchpad) external;

  /// @notice Allows users to stake tokens
  /// @param amount Amount of tokens to stake
  function stake(uint256 amount) external;

  /// @notice Allows users to withdraw staked tokens
  /// @param amount Amount of tokens to withdraw
  function withdraw(uint256 amount) external;

  /// @notice Allows the launchpad to fund new rewards
  /// @param rewardToken Address of the reward token
  /// @param amount Amount of tokens to fund as rewards
  function fundReward(IERC20 rewardToken, uint256 amount) external;

  /// @notice Allows users to claim their share of rewards
  /// @param rewardToken Address of the reward token to claim
  function claim(IERC20 rewardToken) external;

  /// @notice Gets a user's staked amount at a specific block
  /// @param user Address of the user
  /// @param historyIndex Index of the block to check
  /// @return User's staked amount at the specified block
  function getUserStakeAt(address user, uint32 historyIndex) external view returns (uint256);

  /// @notice Gets the total staked amount at a specific block
  /// @param historyIndex Index of the block to check
  /// @return Total staked amount at the specified block
  function getTotalStakeAt(uint32 historyIndex) external view returns (uint256);

  /// @notice Checks if a user has claimed rewards for a specific token
  /// @param user Address of the user
  /// @param rewardToken Address of the reward token
  /// @return Whether the user has claimed the reward
  function hasClaimed(address user, IERC20 rewardToken) external view returns (bool);

  /// @notice The token that users can stake in this contract
  function stakingToken() external view returns (IERC20);

  /// @notice Current staked amount for each user
  function currentStake(address user) external view returns (uint256);

  /// @notice Tracks if a user has claimed a specific reward token
  function claimed(IERC20 rewardToken, address user) external view returns (bool);

  /// @notice Address of the launchpad contract that can fund rewards
  function launchpad() external view returns (address);

  /// @notice Index of the next block to be added to the history
  function historyIndex() external view returns (uint32);
}
