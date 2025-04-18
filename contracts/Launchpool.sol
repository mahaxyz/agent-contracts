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

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {ILaunchpool} from "contracts/interfaces/ILaunchpool.sol";

// TODO add vesting

/// @title Launchpool
/// @notice A staking contract that allows users to stake tokens and receive rewards
/// @dev Inherits from Initializable for proxy support
contract Launchpool is OwnableUpgradeable, ILaunchpool {
  using Checkpoints for Checkpoints.Trace224;
  using SafeERC20 for IERC20Metadata;
  using SafeERC20 for IERC20;

  /// @notice The token that users can stake in this contract
  IERC20Metadata public stakingToken;

  /// @notice Historical record of total staked amounts at different blocks
  Checkpoints.Trace224 private totalStakedHistory;

  /// @notice Historical record of user staked amounts at different blocks
  /// @dev Maps user address to their stake history
  mapping(address => Checkpoints.Trace224) private userStakedHistory;

  /// @notice Current staked amount for each user
  /// @dev Maps user address to their current stake
  mapping(address => uint256) public currentStake;

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

  /// @notice Whether the contract has been killed
  bool public killed;

  /// @notice The name of the token
  string public name;

  /// @notice The symbol of the token
  string public symbol;

  /// @notice The decimals of the token
  uint8 public decimals;

  /// @notice Initializes the contract
  /// @param _stakingToken Address of the token that can be staked
  /// @param _launchpad Address of the launchpad contract
  function initialize(
    string memory _name,
    string memory _symbol,
    address _stakingToken,
    address _owner,
    address _launchpad
  ) public initializer {
    require(_launchpad != address(0), "Invalid launchpad");
    __Ownable_init(_owner);

    stakingToken = IERC20Metadata(_stakingToken);
    launchpad = _launchpad;
    historyIndex = 1; // Start at 1 to avoid confusion with default value 0

    name = _name;
    symbol = _symbol;
    decimals = stakingToken.decimals();

    // emit a transfer event to allow explorers to index the contract
    emit Transfer(address(0), address(this), 1 ether);
    emit Transfer(address(this), address(0), 1 ether);
  }

  /// @inheritdoc ILaunchpool
  function stake(uint256 amount) external {
    require(amount > 0, "Zero stake");
    require(!killed, "Killed");

    currentStake[msg.sender] += amount;
    stakingToken.safeTransferFrom(msg.sender, address(this), amount);

    // Use a single index for both updates
    uint32 currentIndex = historyIndex++;
    userStakedHistory[msg.sender].push(currentIndex, uint224(currentStake[msg.sender]));
    totalStakedHistory.push(currentIndex, uint224(totalStakedHistory.latest() + amount));

    emit Stake(msg.sender, amount);
    emit Transfer(address(0), msg.sender, amount);
  }

  /// @inheritdoc ILaunchpool
  function withdraw(uint256 amount) external {
    require(currentStake[msg.sender] >= amount, "Insufficient stake");

    currentStake[msg.sender] -= amount;
    stakingToken.safeTransfer(msg.sender, amount);

    // Use a single index for both updates
    if (!killed) {
      uint32 currentIndex = historyIndex++;
      userStakedHistory[msg.sender].push(currentIndex, uint224(currentStake[msg.sender]));
      totalStakedHistory.push(currentIndex, uint224(totalStakedHistory.latest() - amount));
    }

    emit Withdraw(msg.sender, amount);
    emit Transfer(msg.sender, address(0), amount);
  }

  /// @inheritdoc ILaunchpool
  function fundReward(IERC20 rewardToken, uint256 amount) external {
    require(amount > 0, "Zero reward");
    require(msg.sender == launchpad, "Invalid caller");
    rewardToken.safeTransferFrom(msg.sender, address(this), amount);

    RewardDrop memory drop = RewardDrop({rewardToken: rewardToken, totalReward: amount, snapshotIndex: historyIndex});
    rewardDrops[rewardToken] = drop;

    emit RewardFunded(rewardToken, amount);
  }

  /// @inheritdoc ILaunchpool
  function claim(IERC20 rewardToken) external {
    RewardDrop storage drop = rewardDrops[rewardToken];
    require(!claimed[rewardToken][msg.sender], "Already claimed");
    claimed[rewardToken][msg.sender] = true;

    uint256 userBal = userStakedHistory[msg.sender].lowerLookup(drop.snapshotIndex);
    uint256 totalBal = totalStakedHistory.lowerLookup(drop.snapshotIndex);

    require(userBal > 0 && totalBal > 0, "Not eligible");

    uint256 reward = (drop.totalReward * userBal) / totalBal;
    IERC20(drop.rewardToken).safeTransfer(msg.sender, reward);

    emit RewardClaimed(msg.sender, rewardToken, reward);
  }

  /// @inheritdoc ILaunchpool
  function getUserStakeAt(address user, uint32 _historyIndex) external view returns (uint256) {
    return userStakedHistory[user].lowerLookup(_historyIndex);
  }

  /// @inheritdoc ILaunchpool
  function getTotalStakeAt(uint32 _historyIndex) external view returns (uint256) {
    return totalStakedHistory.lowerLookup(_historyIndex);
  }

  /// @inheritdoc ILaunchpool
  function hasClaimed(address user, IERC20 rewardToken) external view returns (bool) {
    return claimed[rewardToken][user];
  }

  function kill() external onlyOwner {
    killed = true;
    emit Killed();
    _transferOwnership(address(0));
  }

  function totalSupply() external view returns (uint256) {
    return totalStakedHistory.latest();
  }

  function balanceOf(address account) external view returns (uint256) {
    return currentStake[account];
  }
}
