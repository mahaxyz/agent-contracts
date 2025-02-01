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

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract FixedCurve {
  function calculateBuy(
    uint256 quantityIn,
    uint256 raised,
    uint256 totalRaised
  ) public pure returns (uint256 _amountOut, uint256 _amountIn) {
    uint256 remaining = totalRaised - raised;
    uint256 amountOut = Math.min(quantityIn, remaining);
    return (amountOut, amountOut);
  }

  function calculateSell(
    uint256 quantityOut,
    uint256 raised,
    uint256
  ) public pure returns (uint256 _amountOut, uint256 _amountIn) {
    uint256 amountOut = Math.min(quantityOut, raised);
    return (amountOut, amountOut);
  }
}
