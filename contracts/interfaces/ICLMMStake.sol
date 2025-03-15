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

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IStakeRewardsStrategy} from "contracts/interfaces/IStakeRewardsStrategy.sol";

/// @title ICLMMStake Interface
/// @notice Interface for managing NFT position staking with lock periods and rewards distribution
/// @dev Implements IERC721Receiver for NFT staking functionality
interface ICLMMStake is IERC721Receiver {
  /// @notice Emitted when a lock duration is set for a token ID
  /// @param tokenId The ID of the NFT position
  /// @param lockDuration The duration in seconds that the position will be locked
  event LockDurationSet(uint256 indexed tokenId, uint256 lockDuration);

  /// @notice Emitted when a lock owner is set for a token ID
  /// @param tokenId The ID of the NFT position
  /// @param lockOwner The address of the owner who locked the position
  event LockOwnerSet(uint256 indexed tokenId, address lockOwner);

  /// @notice Emitted when a position is unstaked
  /// @param tokenId The ID of the NFT position being unstaked
  event Unstaked(uint256 indexed tokenId);

  /// @notice Emitted when a rewards strategy is set for a token ID
  /// @param tokenId The ID of the NFT position
  /// @param rewardsStrategy The address of the rewards strategy contract
  /// @param config The configuration data for the rewards strategy
  event RewardsStrategySet(
    uint256 indexed tokenId, IStakeRewardsStrategy rewardsStrategy, IStakeRewardsStrategy.RewardsConfigData config
  );

  /// @notice Emitted when rewards are distributed for a token ID
  /// @param tokenId The ID of the NFT position receiving rewards
  event RewardsDistributed(uint256 indexed tokenId);

  /// @notice Get the lock duration for a specific token ID
  /// @param _tokenId The ID of the NFT position
  /// @return The lock duration in seconds
  function getLockDuration(uint256 _tokenId) external view returns (uint256);

  /// @notice Get the lock owner for a specific token ID
  /// @param _tokenId The ID of the NFT position
  /// @return The address of the lock owner
  function getLockOwner(uint256 _tokenId) external view returns (address);

  /// @notice Unstake an NFT position
  /// @param _tokenId The ID of the NFT position to unstake
  function unstake(uint256 _tokenId) external;

  /// @notice Set the rewards strategy for a specific token ID
  /// @param _tokenId The ID of the NFT position
  /// @param _rewardsStrategy The address of the rewards strategy contract
  /// @param _config The rewards configuration data
  function setRewardsStrategy(
    uint256 _tokenId,
    IStakeRewardsStrategy _rewardsStrategy,
    IStakeRewardsStrategy.RewardsConfigData calldata _config
  ) external;

  /// @notice Distribute rewards for a specific token ID
  /// @param _tokenId The ID of the NFT position to distribute rewards for
  function distributeRewards(uint256 _tokenId) external;
}
