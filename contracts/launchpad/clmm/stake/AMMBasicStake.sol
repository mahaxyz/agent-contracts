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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {IAMMStake} from "contracts/interfaces/IAMMStake.sol";
import {IStakeRewardsStrategy} from "contracts/interfaces/IStakeRewardsStrategy.sol";

abstract contract AMMBasicStake is IAMMStake, Multicall {
  mapping(address owner => mapping(IERC20 token => uint256 lockDuration)) internal _lockDurations;
  mapping(address owner => mapping(IERC20 token => uint256 amount)) internal _lockAmounts;
  mapping(address owner => mapping(IERC20 token => IStakeRewardsStrategy rewardsStrategy)) internal _rewardsStrategies;
  mapping(address owner => mapping(IERC20 token => IStakeRewardsStrategy.RewardsConfigData rewardsConfig)) internal
    _rewardsConfigs;

  /// @inheritdoc IAMMStake
  function stake(IERC20 _token, uint256 _amount, uint256 _lockDuration) external override {
    _token.transferFrom(msg.sender, address(this), _amount);
    _lockDurations[msg.sender][_token] = _lockDuration;
    _lockAmounts[msg.sender][_token] += _amount;
    emit Staked(msg.sender, _token, _amount);
    emit LockDurationSet(msg.sender, _token, _lockDuration);
    emit LockAmountSet(msg.sender, _token, _amount);
  }

  /// @inheritdoc IAMMStake
  function unstake(address _owner, IERC20 _token) external override {
    require(block.timestamp >= _lockDurations[_owner][_token], "Position not unlocked");
    _token.transfer(_owner, _lockAmounts[_owner][_token]);
    _lockDurations[_owner][_token] = 0;
    _lockAmounts[_owner][_token] = 0;
    emit Unstaked(_owner, _token);
  }

  /// @inheritdoc IAMMStake
  function getLockDuration(address _owner, IERC20 _token) external view override returns (uint256) {
    return _lockDurations[_owner][_token];
  }

  /// @inheritdoc IAMMStake
  function getLockAmount(address _owner, IERC20 _token) external view override returns (uint256) {
    return _lockAmounts[_owner][_token];
  }

  /// @inheritdoc IAMMStake
  function setRewardsStrategy(
    address _owner,
    IERC20 _token,
    IStakeRewardsStrategy _rewardsStrategy,
    IStakeRewardsStrategy.RewardsConfigData calldata _config
  ) external override {
    require(_lockAmounts[_owner][_token] > 0, "Invalid sender");
    require(_rewardsStrategy != IStakeRewardsStrategy(address(0)), "Invalid rewards strategy");
    _rewardsStrategies[_owner][_token] = _rewardsStrategy;
    _rewardsConfigs[_owner][_token] = _config;
    emit RewardsStrategySet(_owner, _token, _rewardsStrategy, _config);
  }

  /// @inheritdoc IAMMStake
  function distributeRewards(address _owner, IERC20 _token) external override {
    require(_rewardsStrategies[_owner][_token] != IStakeRewardsStrategy(address(0)), "Invalid rewards strategy");
    // TODO claim fees and distribute rewards
    // _rewardsStrategies[_owner][_token].distributeRewards(_owner, _token, _rewardsConfigs[_owner][_token]);
    emit RewardsDistributed(_owner, _token);
  }
}
