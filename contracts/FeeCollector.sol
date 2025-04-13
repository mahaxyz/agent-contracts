// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IWETH9} from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";

contract FeeCollector is AccessControlEnumerable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
  address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

  address public immutable ODOS;
  IERC20 public immutable CAKE;
  IERC20 public immutable MAHA;
  IWETH9 public immutable WETH;

  uint256 public cakeBurnt;
  uint256 public mahaBurnt;

  bool public swapPaused;

  event FeesSwapped(uint256 cakeAmount, uint256 mahaAmount);
  event SwapPausedToggled(bool isPaused);
  event TokensCollected(address token, uint256 amount);
  event ETHCollected(uint256 amount);
  event ETHReceived(uint256 amount);

  constructor(address _cake, address _maha, address _odos, address _weth) {
    CAKE = IERC20(_cake);
    MAHA = IERC20(_maha);
    WETH = IWETH9(_weth);
    ODOS = _odos;
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(OPERATOR_ROLE, msg.sender);
  }

  receive() external payable {
    if (msg.value > 0) emit ETHReceived(msg.value);
    WETH.deposit{value: msg.value}();
  }

  function toggleSwapPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    swapPaused = !swapPaused;
    emit SwapPausedToggled(swapPaused);
  }

  function swapFeesToTargets(IERC20[] memory _tokens, bytes calldata odosSwapData)
    external
    nonReentrant
    onlyRole(OPERATOR_ROLE)
  {
    require(!swapPaused, "Swapping is paused");

    // give max approval to the odos contract
    for (uint256 i = 0; i < _tokens.length; i++) {
      _tokens[i].approve(address(ODOS), type(uint256).max);
    }

    // Perform the swap via Odos
    (bool success,) = ODOS.call(odosSwapData);
    require(success, "Swap failed");

    // Get balances of CAKE and MAHA after swap
    uint256 cakeBalance = CAKE.balanceOf(address(this));
    uint256 mahaBalance = MAHA.balanceOf(address(this));

    // Burn by sending to dead address
    if (cakeBalance > 0) {
      CAKE.safeTransfer(DEAD, cakeBalance);
      cakeBurnt += cakeBalance;
    }
    if (mahaBalance > 0) {
      MAHA.safeTransfer(DEAD, mahaBalance);
      mahaBurnt += mahaBalance;
    }

    emit FeesSwapped(cakeBalance, mahaBalance);
  }

  function collectToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(token != address(0), "Invalid token address");
    IERC20(token).safeTransfer(msg.sender, amount);
    emit TokensCollected(token, amount);
  }

  function collectETH(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(amount <= address(this).balance, "Insufficient ETH balance");
    (bool success,) = msg.sender.call{value: amount}("");
    require(success, "ETH transfer failed");
    emit ETHCollected(amount);
  }
}
