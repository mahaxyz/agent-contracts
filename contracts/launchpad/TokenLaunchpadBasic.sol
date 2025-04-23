// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝    ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://wagmie.com
// Telegram: https://t.me/mahaxyz
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {IERC20, TokenLaunchpad} from "contracts/launchpad/TokenLaunchpad.sol";

contract TokenLaunchpadBasic is TokenLaunchpad {
  function _distributeFees(address _token0, address _owner, address _token1, uint256 _amount0, uint256 _amount1)
    internal
    override
  {
    address mahaTreasury = 0x7202136d70026DA33628dD3f3eFccb43F62a2469;

    // 40% to MAHA treasury
    // 60% to the owner

    IERC20(_token0).transfer(mahaTreasury, _amount0 * 40 / 100);
    IERC20(_token1).transfer(mahaTreasury, _amount1 * 40 / 100);
    IERC20(_token0).transfer(_owner, _amount0 * 60 / 100);
    IERC20(_token1).transfer(_owner, _amount1 * 60 / 100);
  }
}
