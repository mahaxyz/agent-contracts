// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IVesting} from "../interfaces/IVesting.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Vesting Contract
 * @notice Manages token vesting schedules with an upfront percentage and linear vesting afterward
 */
contract Vesting is IVesting, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;

  // Vesting duration in seconds (1 week)
  uint256 public constant VESTING_DURATION = 7 days;

  // Upfront percentage (25%)
  uint256 public constant UPFRONT_PERCENTAGE = 2500;

  // Mapping of token address -> user address -> vesting details
  mapping(address => mapping(address => VestingInfo)) public userTokenVestingInfo;

  function initialize() external initializer {
    __Ownable_init(msg.sender);
    __ReentrancyGuard_init();
  }

  /// @inheritdoc IVesting
  function createVest(address _token, address _receiver, uint256 _amount) external onlyOwner {
    require(_token != address(0), "Invalid token address");
    require(_receiver != address(0), "Invalid receiver address");
    require(_amount > 0, "Invalid amount");

    // Get the token
    IERC20 token = IERC20(_token);
    token.safeTransferFrom(msg.sender, address(this), _amount);

    // Calculate upfront amount (25%)
    uint256 upfrontAmount = (_amount * UPFRONT_PERCENTAGE) / 10_000;

    // Create vesting schedule
    userTokenVestingInfo[_token][_receiver] =
      VestingInfo({startTime: block.timestamp, totalAmount: _amount, upfrontAmount: upfrontAmount, vestedAmount: 0});

    // Transfer upfront amount immediately to the receiver
    token.safeTransfer(_receiver, upfrontAmount);

    emit TokenVestingStarted(_token, _receiver, _amount, upfrontAmount);
  }

  /// @inheritdoc IVesting
  function claimVestedTokens(address _token) external nonReentrant {
    VestingInfo storage vestingInfo = userTokenVestingInfo[_token][msg.sender];
    require(vestingInfo.totalAmount > 0, "No vesting found");

    // Calculate how much should be released at current time
    uint256 releasable = calculateClaimableAmount(_token, msg.sender);
    require(releasable > 0, "Nothing to claim");

    // Update vested amount
    vestingInfo.vestedAmount += releasable;

    // Transfer tokens
    IERC20(_token).safeTransfer(msg.sender, releasable);

    emit TokenVestingClaimed(_token, msg.sender, releasable);
  }

  /// @inheritdoc IVesting
  function calculateClaimableAmount(address _token, address _account) public view returns (uint256) {
    VestingInfo memory vestingInfo = userTokenVestingInfo[_token][_account];

    // If nothing is vesting or vesting hasn't started yet
    if (vestingInfo.totalAmount == 0 || block.timestamp <= vestingInfo.startTime) {
      return 0;
    }

    // If vesting is complete
    if (block.timestamp >= vestingInfo.startTime + VESTING_DURATION) {
      return vestingInfo.totalAmount - vestingInfo.upfrontAmount - vestingInfo.vestedAmount;
    }

    // Calculate vested amount proportional to time passed (linear vesting)
    uint256 timeElapsed = block.timestamp - vestingInfo.startTime;
    uint256 remainingAmount = vestingInfo.totalAmount - vestingInfo.upfrontAmount;
    uint256 vestedAmount = (remainingAmount * timeElapsed) / VESTING_DURATION;

    // Return amount that can be claimed (subtract what's already been claimed)
    return vestedAmount - vestingInfo.vestedAmount;
  }

  /// @inheritdoc IVesting
  function getVestingInfo(address _token, address _account)
    external
    view
    returns (
      uint256 startTime,
      uint256 totalAmount,
      uint256 upfrontAmount,
      uint256 vestedAmount,
      uint256 claimableAmount
    )
  {
    VestingInfo storage info = userTokenVestingInfo[_token][_account];
    return (
      info.startTime,
      info.totalAmount,
      info.upfrontAmount,
      info.vestedAmount,
      calculateClaimableAmount(_token, _account)
    );
  }

  /// @inheritdoc IVesting
  function emergencyWithdrawal(address _token, address _to) external onlyOwner {
    require(_to != address(0), "Invalid recipient");
    IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));
  }
}
