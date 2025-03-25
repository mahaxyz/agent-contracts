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

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IReferralDistributor} from "contracts/interfaces/IReferralDistributor.sol";

/// @title ReferralDistributor
/// @notice Distributes referral fees to the referral destination
contract ReferralDistributor is IReferralDistributor, AccessControlEnumerable {
  using SafeERC20 for IERC20;

  bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

  // accounting
  mapping(bytes32 poolId => mapping(address token => uint256 balance)) public tokenBalances;

  constructor(address _admin) {
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(DISTRIBUTOR_ROLE, _admin);
  }

  /// @inheritdoc IReferralDistributor
  function collectReferralFees(address _token0, address _token1, uint256 _amount0, uint256 _amount1) external {
    bytes32 poolId = keccak256(abi.encode(_token0, _token1));
    tokenBalances[poolId][_token0] += _amount0;
    tokenBalances[poolId][_token1] += _amount1;

    IERC20(_token0).safeTransferFrom(msg.sender, address(this), _amount0);
    IERC20(_token1).safeTransferFrom(msg.sender, address(this), _amount1);

    emit ReferralFeesCollected(_token0, _token1, _amount0, _amount1);
  }

  /// @inheritdoc IReferralDistributor
  function distributeReferralFees(ReferralDistribution memory _distribution) external onlyRole(DISTRIBUTOR_ROLE) {
    _distributeReferralFees(_distribution);
  }

  /// @inheritdoc IReferralDistributor
  function distributeReferralFeesMultiple(ReferralDistribution[] memory _distributions)
    external
    onlyRole(DISTRIBUTOR_ROLE)
  {
    for (uint256 i = 0; i < _distributions.length; i++) {
      _distributeReferralFees(_distributions[i]);
    }
  }

  /// @dev Distributes referral fees to the referral destination
  /// @param _distribution The referral distribution
  function _distributeReferralFees(ReferralDistribution memory _distribution) internal {
    IERC20(_distribution.token0).safeTransfer(_distribution.destination, _distribution.amount0);
    IERC20(_distribution.token1).safeTransfer(_distribution.destination, _distribution.amount1);
    emit ReferralFeesDistributed(_distribution);

    // update accounting to make sure we don't distribute more than we have
    bytes32 poolId = keccak256(abi.encode(_distribution.token0, _distribution.token1));
    tokenBalances[poolId][_distribution.token0] -= _distribution.amount0;
    tokenBalances[poolId][_distribution.token1] -= _distribution.amount1;
  }
}
