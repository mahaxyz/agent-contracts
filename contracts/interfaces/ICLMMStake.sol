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

interface ICLMMStake is IERC721Receiver {
  event LockDurationSet(uint256 indexed tokenId, uint256 lockDuration);
  event LockOwnerSet(uint256 indexed tokenId, address lockOwner);
  event Unstaked(uint256 indexed tokenId);
  event RewardsStrategySet(
    uint256 indexed tokenId, IStakeRewardsStrategy rewardsStrategy, IStakeRewardsStrategy.RewardsConfigData config
  );
  event RewardsDistributed(uint256 indexed tokenId);

  function getLockDuration(uint256 _tokenId) external view returns (uint256);

  function getLockOwner(uint256 _tokenId) external view returns (address);

  function unstake(uint256 _tokenId) external;

  function setRewardsStrategy(
    uint256 _tokenId,
    IStakeRewardsStrategy _rewardsStrategy,
    IStakeRewardsStrategy.RewardsConfigData calldata _config
  ) external;

  function distributeRewards(uint256 _tokenId) external;
}
