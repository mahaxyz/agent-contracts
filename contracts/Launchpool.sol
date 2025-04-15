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

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

/// @title Launchpool
/// @notice A staking contract that allows users to stake tokens and receive rewards
/// @dev Inherits from Initializable for proxy support
contract Launchpool is Initializable {
  using Checkpoints for Checkpoints.Trace224;
  using SafeERC20 for IERC20;

  /// @notice The token that users can stake in this contract
  IERC20 public stakingToken;

  /// @notice Historical record of total staked amounts at different blocks
  Checkpoints.Trace224 private totalStakedHistory;

  /// @notice Historical record of user staked amounts at different blocks
  /// @dev Maps user address to their stake history
  mapping(address => Checkpoints.Trace224) private userStakedHistory;

  /// @notice Current staked amount for each user
  /// @dev Maps user address to their current stake
  mapping(address => uint256) public currentStake;

  /// @notice Struct containing reward drop information
  /// @param rewardToken Address of the reward token
  /// @param totalReward Total amount of tokens to distribute as rewards
  /// @param snapshotBlock Block number when the reward drop was created
  struct RewardDrop {
    IERC20 rewardToken;
    uint256 totalReward;
    uint32 snapshotBlock;
  }

  /// @notice Tracks if a user has claimed a specific reward token
  /// @dev Maps reward token address to user address to claim status
  mapping(IERC20 rewardToken => mapping(address user => bool claimed)) public claimed;

  /// @notice Stores reward drop information for each reward token
  /// @dev Maps reward token address to RewardDrop struct
  mapping(IERC20 rewardToken => RewardDrop) public rewardDrops;

  /// @notice Address of the launchpad contract that can fund rewards
  address public launchpad;

  /// @notice Index of the next block to be added to the history
  uint32 public historyIndex;

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

  /// @dev Reserved storage space for future upgrades
  uint256[45] private __gap;

  /// @notice Initializes the contract
  /// @param _stakingToken Address of the token that can be staked
  /// @param _launchpad Address of the launchpad contract
  function initialize(address _stakingToken, address _launchpad) public initializer {
    require(_launchpad != address(0), "Invalid launchpad");

    stakingToken = IERC20(_stakingToken);
    launchpad = _launchpad;
  }

  /// @notice Allows users to stake tokens
  /// @param amount Amount of tokens to stake
  function stake(uint256 amount) external {
    require(amount > 0, "Zero stake");

    currentStake[msg.sender] += amount;
    stakingToken.safeTransferFrom(msg.sender, address(this), amount);

    userStakedHistory[msg.sender].push(historyIndex++, uint224(currentStake[msg.sender]));
    totalStakedHistory.push(historyIndex++, uint224(totalStakedHistory.latest() + amount));

    emit Stake(msg.sender, amount);
  }

  /// @notice Allows users to withdraw staked tokens
  /// @param amount Amount of tokens to withdraw
  function withdraw(uint256 amount) external {
    require(currentStake[msg.sender] >= amount, "Insufficient stake");

    currentStake[msg.sender] -= amount;
    stakingToken.safeTransfer(msg.sender, amount);

    userStakedHistory[msg.sender].push(historyIndex++, uint224(currentStake[msg.sender]));
    totalStakedHistory.push(historyIndex++, uint224(totalStakedHistory.latest() - amount));

    emit Withdraw(msg.sender, amount);
  }

  /// @notice Allows the launchpad to fund new rewards
  /// @param rewardToken Address of the reward token
  /// @param amount Amount of tokens to fund as rewards
  function fundReward(IERC20 rewardToken, uint256 amount) external {
    require(amount > 0, "Zero reward");
    require(msg.sender == launchpad, "Invalid caller");
    rewardToken.safeTransferFrom(msg.sender, address(this), amount);

    RewardDrop memory drop =
      RewardDrop({rewardToken: rewardToken, totalReward: amount, snapshotBlock: uint32(block.number)});
    rewardDrops[rewardToken] = drop;

    emit RewardFunded(rewardToken, amount);
  }

  /// @notice Allows users to claim their share of rewards
  /// @param rewardToken Address of the reward token to claim
  function claim(IERC20 rewardToken) external {
    RewardDrop storage drop = rewardDrops[rewardToken];
    require(!claimed[rewardToken][msg.sender], "Already claimed");

    claimed[rewardToken][msg.sender] = true;

    uint256 userBal = userStakedHistory[msg.sender].lowerLookup(drop.snapshotBlock);
    uint256 totalBal = totalStakedHistory.lowerLookup(drop.snapshotBlock);

    require(userBal > 0 && totalBal > 0, "Not eligible");

    uint256 reward = (drop.totalReward * userBal) / totalBal;
    IERC20(drop.rewardToken).safeTransfer(msg.sender, reward);

    emit RewardClaimed(msg.sender, rewardToken, reward);
  }

  /// @notice Gets a user's staked amount at a specific block
  /// @param user Address of the user
  /// @param historyIndex Index of the block to check
  /// @return User's staked amount at the specified block
  function getUserStakeAt(address user, uint32 historyIndex) external view returns (uint256) {
    return userStakedHistory[user].lowerLookup(historyIndex);
  }

  /// @notice Gets the total staked amount at a specific block
  /// @param historyIndex Index of the block to check
  /// @return Total staked amount at the specified block
  function getTotalStakeAt(uint32 historyIndex) external view returns (uint256) {
    return totalStakedHistory.lowerLookup(historyIndex);
  }

  /// @notice Checks if a user has claimed rewards for a specific token
  /// @param user Address of the user
  /// @param rewardToken Address of the reward token
  /// @return Whether the user has claimed the reward
  function hasClaimed(address user, IERC20 rewardToken) external view returns (bool) {
    return claimed[rewardToken][user];
  }
}
