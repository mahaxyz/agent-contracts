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

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH9} from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";
import {ICLMMAdapter, PoolKey} from "contracts/interfaces/ICLMMAdapter.sol";

abstract contract BaseAdapter is ICLMMAdapter, Initializable {
  using SafeERC20 for IERC20;

  address public launchpad;
  address public ODOS;
  IWETH9 public WETH9;
  mapping(IERC20 token => LaunchTokenParams params) public launchParams;
  address internal _me;

  function __BaseAdapter_init(address _launchpad, address _WETH9, address _odos) internal {
    launchpad = _launchpad;
    _me = address(this);
    WETH9 = IWETH9(_WETH9);
    ODOS = _odos;
  }

  function launchedTokens(IERC20 _token) external view returns (bool launched) {
    launched = launchParams[_token].pool != address(0);
  }

  function getPool(IERC20 _token) external view returns (address pool) {
    return address(launchParams[_token].pool);
  }

  receive() external payable {}

  /// @dev Refund tokens to the owner
  /// @param _token The token to refund
  function _refundTokens(IERC20 _token) internal {
    uint256 remaining = _token.balanceOf(address(this));
    if (remaining == 0) return;
    if (_token == WETH9) {
      WETH9.withdraw(remaining);
      payable(msg.sender).transfer(remaining);
    } else {
      _token.safeTransfer(msg.sender, remaining);
    }
  }
}
