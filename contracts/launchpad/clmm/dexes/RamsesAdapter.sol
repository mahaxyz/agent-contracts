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

import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";

abstract contract RamsesAdapter is ICLMMAdapter {
  address public immutable LAUNCHPAD;
  mapping(address token => bool) public launchedTokens;

  constructor(address _launchpad) {
    LAUNCHPAD = _launchpad;
  }

  function addSingleSidedLiquidity(
    address _tokenBase,
    address _tokenQuote,
    uint256 _amountBaseBeforeTick,
    uint256 _amountBaseAfterTick,
    int128 _tick0,
    int128 _tick1,
    int128 _tick2
  ) external {
    require(msg.sender == LAUNCHPAD, "!launchpad");
    require(launchedTokens[_tokenBase], "!launched");
    launchedTokens[_tokenBase] = true;

    // add liquidity to the various tick ranges
  }

  function claimFees(address _token) external returns (uint256 fee0, uint256 fee1) {
    require(msg.sender == LAUNCHPAD, "!launchpad");
    IPool pool = IPool(_token);
    (fee0, fee1) = pool.claimFees();

    IERC20(pool.token0()).transfer(msg.sender, fee0);
    IERC20(pool.token1()).transfer(msg.sender, fee1);

    // automatically send fees to the nile gauge contract
    // automatically send fees to the launchpad contract
  }

  function rebalanceLiquidityAfterGraduation(address _token) external {
    require(msg.sender == _token, "!token");
    require(launchedTokens[_token], "!launched");

    if (currentTick > middleTick) {
      // token has graduated
      // remove liquidity from the graudated tick range and move it to the full range
      // trigger the launchpad to distribute fees
    }
  }
}
