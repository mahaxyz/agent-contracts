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

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract IGoPlusLocker is IERC721Receiver {
  struct FeeStruct {
    string name; // name by which the fee is accessed
    uint256 lpFee; // 100 = 1%, 10,000 = 100%
    uint256 collectFee; // 100 = 1%, 10,000 = 100%
    uint256 lockFee; // in amount tokens
    address lockFeeToken; // address(0) = ETH otherwise ERC20 address expected
  }

  // struct LockInfo {
  //   uint256 lockId;
  //   INonfungiblePositionManager nftPositionManager;
  //   address pendingOwner;
  //   address owner;
  //   address collector;
  //   address pool;
  //   uint256 collectFee;
  //   uint256 nftId;
  //   uint256 startTime;
  //   uint256 endTime;
  // }

  function FEE_DENOMINATOR() external view returns (uint256);
  function nextLockId() external view returns (uint256);
  function fees(bytes32 nameHash) external view returns (FeeStruct memory);
  function feeReceiver() external view returns (address);
  function customFeeSigner() external view returns (address);
  // function locks(uint256 lockId) external view returns (LockInfo memory);
  function disabledSigs(bytes memory) external view returns (bool);
  function addOrUpdateFee(
    string memory name_,
    uint256 lpFee_,
    uint256 collectFee_,
    uint256 lockFee_,
    address lockFeeToken_
  ) external;
  function removeFee(string memory name_) external;
  function updateFeeReceiver(address feeReceiver_) external;
  function updateFeeSigner(address feeSigner_) external;
  function addSupportedNftManager(address nftManager_) external;
  function disableSig(bytes memory sig) external;
  function supportedNftManager(address nftManager_) external view returns (bool);
  function isSupportedFeeName(string memory name_) external view returns (bool);
  function getFee(string memory name_) external view returns (FeeStruct memory);
  function lock(
    INonfungiblePositionManager nftManager_,
    uint256 nftId_,
    address owner_,
    address collector_,
    uint256 endTime_,
    string memory feeName_
  ) external payable returns (uint256 lockId);
  function lockWithCustomFee(
    INonfungiblePositionManager nftManager_,
    uint256 nftId_,
    address owner_,
    address collector_,
    uint256 endTime_,
    bytes memory signature_,
    FeeStruct memory feeObj_
  ) external payable returns (uint256 lockId);
  function transferLock(uint256 lockId_, address newOwner_) external;
  function acceptLock(uint256 lockId_) external;
  function increaseLiquidity(uint256 lockId_, INonfungiblePositionManager.IncreaseLiquidityParams calldata params)
    external
    payable
    returns (uint128 liquidity, uint256 amount0, uint256 amount1);
  function decreaseLiquidity(uint256 lockId_, INonfungiblePositionManager.DecreaseLiquidityParams calldata params)
    external
    payable
    returns (uint256 amount0, uint256 amount1);
  function unlock(uint256 lockId_) external;
  function relock(uint256 lockId_, uint256 endTime_) external;
  function collect(uint256 lockId_, address recipient_, uint128 amount0Max_, uint128 amount1Max_)
    external
    returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1);
  function setCollectAddress(uint256 lockId_, address collector_) external;
  function adminRefundEth(uint256 amount_, address payable receiver_) external;
  function adminRefundERC20(address token_, address receiver_, uint256 amount_) external;
  function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
    external
    pure
    returns (bytes4);
  function getUserLocks(address user) external view returns (uint256[] memory lockIds);
}
