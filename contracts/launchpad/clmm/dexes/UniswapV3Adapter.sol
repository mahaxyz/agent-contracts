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

import {IPool} from "contracts/aerodrome/interfaces/IPool.sol";
import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";

abstract contract UniswapV3Adapter is ICLMMAdapter {
  address public immutable LAUNCHPAD;

  constructor(address _launchpad) {
    LAUNCHPAD = _launchpad;
  }

  function claimFees(address _token) external returns (uint256 fee0, uint256 fee1) {
    require(msg.sender == LAUNCHPAD, "!launchpad");
    IPool pool = IPool(_token);
    (fee0, fee1) = pool.claimFees();

    IERC20(pool.token0()).transfer(msg.sender, fee0);
    IERC20(pool.token1()).transfer(msg.sender, fee1);

    // automatically send fees to the
  }

  function rebalanceLiquidityAfterGraduation(address _tokenBase) external {
    require(msg.sender == _tokenBase, "!token");
    if (currentTick > middleTick) {
      // token has graduated
      // remove liquidity from the graudated tick range and move it to the full range
      // trigger the launchpad to distribute fees
    }
  }
}
