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

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {ICLMMStake, IERC721Receiver} from "contracts/interfaces/ICLMMStake.sol";
import {IStakeRewardsStrategy} from "contracts/interfaces/IStakeRewardsStrategy.sol";

abstract contract CLMMBasicStake is ICLMMStake, Multicall {
  IERC721 public immutable NFT_POSITION_MANAGER;

  /// @notice Mapping of token IDs to their lock durations
  mapping(uint256 tokenId => uint256 lockDuration) internal _lockDurations;

  /// @notice Mapping of token IDs to their lock owners
  mapping(uint256 tokenId => address lockOwner) internal _lockOwners;

  /// @notice Mapping of token IDs to their rewards strategies
  mapping(uint256 tokenId => IStakeRewardsStrategy rewardsStrategy) internal _rewardsStrategies;

  /// @notice Mapping of token IDs to their rewards configurations
  mapping(uint256 tokenId => IStakeRewardsStrategy.RewardsConfigData rewardsConfig) internal _rewardsConfigs;

  constructor(address _nftPositionManager) {
    NFT_POSITION_MANAGER = IERC721(_nftPositionManager);
  }

  function onERC721Received(address, address from, uint256 tokenId, bytes calldata data)
    external
    override
    returns (bytes4)
  {
    require(msg.sender == address(NFT_POSITION_MANAGER), "Invalid sender");
    if (data.length > 0) {
      uint256 lockDuration = abi.decode(data, (uint256));
      _lockDurations[tokenId] = lockDuration;
      emit LockDurationSet(tokenId, lockDuration);
    }
    _lockOwners[tokenId] = from;
    emit LockOwnerSet(tokenId, from);
    return IERC721Receiver.onERC721Received.selector;
  }

  /// @inheritdoc ICLMMStake
  function unstake(uint256 _tokenId) external override {
    require(block.timestamp >= _lockDurations[_tokenId], "Position not unlocked");
    require(_lockOwners[_tokenId] == msg.sender, "Invalid sender");
    NFT_POSITION_MANAGER.transferFrom(address(this), msg.sender, _tokenId);
    _lockDurations[_tokenId] = 0;
    _lockOwners[_tokenId] = address(0);
    emit Unstaked(_tokenId);
  }

  /// @inheritdoc ICLMMStake
  function getLockDuration(uint256 _tokenId) external view override returns (uint256) {
    return _lockDurations[_tokenId];
  }

  /// @inheritdoc ICLMMStake
  function getLockOwner(uint256 _tokenId) external view override returns (address) {
    return _lockOwners[_tokenId];
  }

  /// @inheritdoc ICLMMStake
  function setRewardsStrategy(
    uint256 _tokenId,
    IStakeRewardsStrategy _rewardsStrategy,
    IStakeRewardsStrategy.RewardsConfigData calldata _config
  ) external override {
    require(_lockOwners[_tokenId] == msg.sender, "Invalid sender");
    require(_rewardsStrategy != IStakeRewardsStrategy(address(0)), "Invalid rewards strategy");
    _rewardsStrategies[_tokenId] = _rewardsStrategy;
    _rewardsConfigs[_tokenId] = _config;
    emit RewardsStrategySet(_tokenId, _rewardsStrategy, _config);
  }

  /// @inheritdoc ICLMMStake
  function distributeRewards(uint256 _tokenId) external override {
    require(_rewardsStrategies[_tokenId] != IStakeRewardsStrategy(address(0)), "Invalid rewards strategy");
    // TODO claim fees and distribute rewards
    // _rewardsStrategies[_tokenId].distributeRewards(_tokenId, _rewardsConfigs[_tokenId]);
    emit RewardsDistributed(_tokenId);
  }
}
