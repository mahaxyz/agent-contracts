// SPDX-License-Identifier: MIT

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Telegram: https://t.me/mahaxyz
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC721Receiver, IFreeUniV3LPLocker} from "contracts/interfaces/IFreeUniV3LPLocker.sol";
import {IClPoolFactory} from "contracts/interfaces/thirdparty/IClPoolFactory.sol";
import {INonfungiblePositionManager} from "contracts/interfaces/thirdparty/INonfungiblePositionManager.sol";

/// @title FreeUniV3LPLocker
/// @notice Contract for locking Uniswap V3 LP positions
/// @dev Implements the IFreeUniV3LPLocker interface
contract FreeUniV3LPLocker is IFreeUniV3LPLocker, Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.UintSet;

  uint256 public nextLockId = 1;

  /// supported nftPositionMangers
  EnumerableSet.AddressSet private nftManagers;

  /// lock details
  mapping(uint256 lockId => LockInfo) public locks;

  /// List of lock ids for user
  mapping(address => EnumerableSet.UintSet) private userLocks;

  /// @notice Modifier to check if the caller is the owner of a lock
  /// @param lockId The ID of the lock to check
  modifier validLockOwner(uint256 lockId) {
    require(lockId < nextLockId, "Invalid lockId");
    require(locks[lockId].owner == _msgSender(), "Not lock owner");
    _;
  }

  /// @notice Constructor
  /// @param nftManager_ The address of the initial NFT position manager
  constructor(address nftManager_) Ownable(_msgSender()) {
    nftManagers.add(nftManager_);
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function addSupportedNftManager(address nftManager_) external onlyOwner {
    nftManagers.add(nftManager_);
    emit OnAddNftManger(nftManager_);
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function supportedNftManager(address nftManager_) public view returns (bool) {
    return nftManagers.contains(nftManager_);
  }

  /// @notice Gets the pool address for a given NFT position
  /// @param nftManager_ The NFT position manager contract
  /// @param nftId_ The ID of the NFT position
  /// @return pool The address of the Uniswap V3 pool
  function _getPool(INonfungiblePositionManager nftManager_, uint256 nftId_) internal view returns (address pool) {
    (,, address token0, address token1, uint24 fee,,,,,,,) = nftManager_.positions(nftId_);
    IClPoolFactory factory = IClPoolFactory(nftManager_.factory());
    pool = factory.getPool(token0, token1, fee);
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function lock(
    INonfungiblePositionManager nftManager_,
    uint256 nftId_,
    address owner_,
    address collector_,
    uint256 endTime_
  ) external returns (uint256 lockId) {
    require(collector_ != address(0), "CollectAddress invalid");
    require(endTime_ > block.timestamp, "EndTime <= currentTime");
    require(supportedNftManager(address(nftManager_)), "nftPositionManager not supported");

    nftManager_.safeTransferFrom(_msgSender(), address(this), nftId_);
    address pool = _getPool(nftManager_, nftId_);

    LockInfo memory newLock = LockInfo({
      lockId: nextLockId,
      nftPositionManager: nftManager_,
      pendingOwner: address(0),
      owner: owner_,
      collector: collector_,
      pool: pool,
      nftId: nftId_,
      startTime: block.timestamp,
      endTime: endTime_
    });
    locks[newLock.lockId] = newLock;
    userLocks[owner_].add(newLock.lockId);
    nextLockId++;

    emit OnLock(newLock.lockId, address(nftManager_), owner_, nftId_, endTime_);
    return newLock.lockId;
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function transferLock(uint256 lockId_, address newOwner_) external validLockOwner(lockId_) {
    locks[lockId_].pendingOwner = newOwner_;
    emit OnLockPendingTransfer(lockId_, _msgSender(), newOwner_);
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function acceptLock(uint256 lockId_) external {
    require(lockId_ < nextLockId, "Invalid lockId");
    address newOwner = _msgSender();
    /// check new owner
    require(newOwner == locks[lockId_].pendingOwner, "Not pendingOwner");
    /// emit event
    emit OnLockTransferred(lockId_, locks[lockId_].owner, newOwner);
    /// remove lockId from owner
    userLocks[locks[lockId_].owner].remove(lockId_);
    /// add lockId to new owner
    userLocks[newOwner].add(lockId_);
    /// set owner
    locks[lockId_].pendingOwner = address(0);
    locks[lockId_].owner = newOwner;
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function increaseLiquidity(uint256 lockId_, INonfungiblePositionManager.IncreaseLiquidityParams calldata params)
    external
    payable
    nonReentrant
    returns (uint128 liquidity, uint256 amount0, uint256 amount1)
  {
    LockInfo memory userLock = locks[lockId_];
    require(userLock.nftId == params.tokenId, "Invalid NFT_ID");

    (,, address token0, address token1,,,,,,,,) = userLock.nftPositionManager.positions(userLock.nftId);

    uint256 balance0Before = IERC20(token0).balanceOf(address(this));
    uint256 balance1Before = IERC20(token1).balanceOf(address(this));

    IERC20(token0).safeTransferFrom(_msgSender(), address(this), params.amount0Desired);
    IERC20(token1).safeTransferFrom(_msgSender(), address(this), params.amount1Desired);
    IERC20(token0).approve(address(userLock.nftPositionManager), params.amount0Desired);
    IERC20(token1).approve(address(userLock.nftPositionManager), params.amount1Desired);

    (liquidity, amount0, amount1) = userLock.nftPositionManager.increaseLiquidity(params);

    uint256 balance0diff = IERC20(token0).balanceOf(address(this)) - balance0Before;
    uint256 balance1diff = IERC20(token1).balanceOf(address(this)) - balance1Before;
    if (balance0diff > 0) IERC20(token0).safeTransfer(_msgSender(), balance0diff);
    if (balance1diff > 0) IERC20(token1).safeTransfer(_msgSender(), balance1diff);

    emit OnIncreaseLiquidity(lockId_);
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function decreaseLiquidity(uint256 lockId_, INonfungiblePositionManager.DecreaseLiquidityParams calldata params)
    external
    payable
    validLockOwner(lockId_)
    nonReentrant
    returns (uint256 amount0, uint256 amount1)
  {
    LockInfo memory userLock = locks[lockId_];
    require(userLock.nftId == params.tokenId, "Invalid NFT_ID");
    require(userLock.endTime < block.timestamp, "NOT YET");
    _collect(lockId_, _msgSender(), type(uint128).max, type(uint128).max); // collect fees
    (amount0, amount1) = userLock.nftPositionManager.decreaseLiquidity(params);
    userLock.nftPositionManager.collect(
      INonfungiblePositionManager.CollectParams(userLock.nftId, userLock.owner, type(uint128).max, type(uint128).max)
    );
    emit OnDecreaseLiquidity(lockId_);
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function unlock(uint256 lockId_) external validLockOwner(lockId_) {
    LockInfo memory userLock = locks[lockId_];
    require(userLock.endTime < block.timestamp, "Not yet");

    _collect(lockId_, userLock.owner, type(uint128).max, type(uint128).max);

    userLock.nftPositionManager.safeTransferFrom(address(this), userLock.owner, userLock.nftId);
    userLocks[userLock.owner].remove(lockId_);

    emit OnUnlock(lockId_, userLock.owner, userLock.nftId, block.timestamp);

    delete locks[lockId_]; // clear the state for this lock (reset all values to zero)
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function relock(uint256 lockId_, uint256 endTime_) external validLockOwner(lockId_) nonReentrant {
    LockInfo storage userLock = locks[lockId_];
    require(endTime_ > userLock.endTime, "EndTime <= currentEndTiem");
    require(endTime_ > block.timestamp, "EndTime <= now");
    userLock.endTime = endTime_;
    emit OnRelock(lockId_, userLock.endTime);
  }

  /// @notice Private collect function, wrap this in re-entrancy guard calls
  /// @param lockId_ The ID of the lock
  /// @param recipient_ The address to receive the fees
  /// @param amount0Max_ The maximum amount of token0 to collect
  /// @param amount1Max_ The maximum amount of token1 to collect
  /// @return amount0 The amount of token0 collected
  /// @return amount1 The amount of token1 collected
  function _collect(uint256 lockId_, address recipient_, uint128 amount0Max_, uint128 amount1Max_)
    private
    returns (uint256 amount0, uint256 amount1)
  {
    LockInfo memory userLock = locks[lockId_];
    require(userLock.owner == _msgSender() || userLock.collector == _msgSender(), "Not owner");
    (amount0, amount1) = userLock.nftPositionManager.collect(
      INonfungiblePositionManager.CollectParams(userLock.nftId, recipient_, amount0Max_, amount1Max_)
    );
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function collect(uint256 lockId_, address recipient_, uint128 amount0Max_, uint128 amount1Max_)
    external
    nonReentrant
    returns (uint256 amount0, uint256 amount1)
  {
    (amount0, amount1) = _collect(lockId_, recipient_, amount0Max_, amount1Max_);
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function setCollectAddress(uint256 lockId_, address collector_) external validLockOwner(lockId_) nonReentrant {
    require(collector_ != address(0), "COLLECT_ADDR");
    LockInfo storage userLock = locks[lockId_];
    userLock.collector = collector_;
    emit OnSetCollector(lockId_, collector_);
  }

  /// @notice Returns just the liquidity value from a position
  /// @param nftPositionManager_ The NFT position manager contract
  /// @param tokenId_ The ID of the NFT position
  /// @return liquidity The amount of liquidity in the position
  function _getLiquidity(INonfungiblePositionManager nftPositionManager_, uint256 tokenId_)
    private
    view
    returns (uint128)
  {
    (,,,,,,, uint128 liquidity,,,,) = nftPositionManager_.positions(tokenId_);
    return liquidity;
  }

  function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }

  /// @inheritdoc IFreeUniV3LPLocker
  function getUserLocks(address user) external view returns (uint256[] memory lockIds) {
    return userLocks[user].values();
  }
}
