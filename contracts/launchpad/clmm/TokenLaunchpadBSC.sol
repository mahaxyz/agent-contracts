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

contract TokenLaunchpadBSC is TokenLaunchpad {
  function _distributeFees(address _token0, address _owner, address _token1, uint256 _amount0, uint256 _amount1)
    internal
    override
  {
    address mahaTreasury = address(0); // TODO: change to BSC treasury

    // 40% to MAHA treasury
    // 60% to the owner

    IERC20(_token0).transfer(mahaTreasury, _amount0 * 40 / 100);
    IERC20(_token1).transfer(mahaTreasury, _amount1 * 40 / 100);
    IERC20(_token0).transfer(_owner, _amount0 * 60 / 100);
    IERC20(_token1).transfer(_owner, _amount1 * 60 / 100);
  }
}
