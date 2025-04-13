// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IWETH9} from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";

/// @title FeeCollector - Contract for collecting and burning fees in CAKE and MAHA tokens
/// @notice Handles fee collection, swapping via ODOS, and burning of tokens
contract FeeCollector is AccessControlEnumerable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  /// @notice Role identifier for operators who can execute fee swaps
  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
  /// @notice Dead address where tokens are sent to be burned
  address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

  /// @notice Address of the ODOS router contract
  address public immutable ODOS;
  /// @notice CAKE token contract
  IERC20 public immutable CAKE;
  /// @notice MAHA token contract
  IERC20 public immutable MAHA;
  /// @notice WETH token contract
  IWETH9 public immutable WETH;

  /// @notice Total amount of CAKE tokens that have been burned
  uint256 public cakeBurnt;
  /// @notice Total amount of MAHA tokens that have been burned
  uint256 public mahaBurnt;

  /// @notice Flag indicating if swapping is currently paused
  bool public swapPaused;

  /// @notice Emitted when fees are swapped and burned
  /// @param cakeAmount Amount of CAKE tokens burned
  /// @param mahaAmount Amount of MAHA tokens burned
  event FeesSwapped(uint256 cakeAmount, uint256 mahaAmount);

  /// @notice Emitted when swap pause state is toggled
  /// @param isPaused New pause state
  event SwapPausedToggled(bool isPaused);

  /// @notice Emitted when tokens are collected by admin
  /// @param token Address of collected token
  /// @param amount Amount collected
  event TokensCollected(address token, uint256 amount);

  /// @notice Emitted when ETH is collected by admin
  /// @param amount Amount of ETH collected
  event ETHCollected(uint256 amount);

  /// @notice Emitted when ETH is received by the contract
  /// @param amount Amount of ETH received
  event ETHReceived(uint256 amount);

  /// @notice Initializes the contract with token addresses
  /// @param _cake Address of CAKE token
  /// @param _maha Address of MAHA token
  /// @param _odos Address of ODOS router
  /// @param _weth Address of WETH token
  constructor(address _cake, address _maha, address _odos, address _weth) {
    CAKE = IERC20(_cake);
    MAHA = IERC20(_maha);
    WETH = IWETH9(_weth);
    ODOS = _odos;
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(OPERATOR_ROLE, msg.sender);
  }

  /// @notice Handles receiving ETH and wraps it to WETH
  receive() external payable {
    if (msg.value > 0) emit ETHReceived(msg.value);
    WETH.deposit{value: msg.value}();
  }

  /// @notice Toggles the pause state for swapping
  /// @dev Can only be called by admin
  function toggleSwapPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    swapPaused = !swapPaused;
    emit SwapPausedToggled(swapPaused);
  }

  /// @notice Swaps collected fees to CAKE and MAHA and burns them
  /// @dev Can only be called by operator when not paused
  /// @param _tokens Array of token addresses to swap
  /// @param odosSwapData Encoded swap data for ODOS router
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

  /// @notice Allows admin to collect any tokens from the contract
  /// @dev Can only be called by admin
  /// @param token Address of token to collect
  /// @param amount Amount of tokens to collect
  function collectToken(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(token != address(0), "Invalid token address");
    IERC20(token).safeTransfer(msg.sender, amount);
    emit TokensCollected(token, amount);
  }

  /// @notice Allows admin to collect ETH from the contract
  /// @dev Can only be called by admin
  /// @param amount Amount of ETH to collect
  function collectETH(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(amount <= address(this).balance, "Insufficient ETH balance");
    (bool success,) = msg.sender.call{value: amount}("");
    require(success, "ETH transfer failed");
    emit ETHCollected(amount);
  }
}
