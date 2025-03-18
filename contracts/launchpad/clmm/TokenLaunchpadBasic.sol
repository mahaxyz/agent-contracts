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

import {IERC20, TokenLaunchpad} from "./TokenLaunchpad.sol";

contract TokenLaunchpadBasic is TokenLaunchpad {
  function _distributeFees(address _token0, address _token1, uint256 _amount0, uint256 _amount1) internal override {
    IERC20(_token0).transfer(feeDestination, _amount0);
    IERC20(_token1).transfer(feeDestination, _amount1);
  }
}
