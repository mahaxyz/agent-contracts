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
  uint256 public totalTokensToSell = 250_000_000 ether; // 25% of the supply to sell

  function calculateBuy(uint256 tokensToBuy, uint256 assetsRaised, uint256 totalAssetRaise)
    public
    view
    returns (uint256 _tokensOut, uint256 _assetsIn)
  {
    uint256 priceE18 = totalAssetRaise * 1 ether / totalTokensToSell; // price in terms of 1 TOKEN = ? ASSET
    uint256 tokensSold = assetsRaised * 1 ether / priceE18;
    uint256 remainingToSell = totalTokensToSell - tokensSold;

    _tokensOut = Math.min(tokensToBuy, remainingToSell);
    _assetsIn = _tokensOut * priceE18 / 1 ether;
  }

  function calculateSell(uint256 tokensToSell, uint256 assetsRaised, uint256 totalAssetRaise)
    public
    view
    returns (uint256 _assetsOut, uint256 _tokensIn)
  {
    uint256 priceE18 = totalAssetRaise * 1 ether / totalTokensToSell; // price in terms of 1 TOKEN = ? ASSET
    uint256 tokensSold = assetsRaised * 1 ether / priceE18;
    _assetsOut = tokensToSell * priceE18 / 1 ether;
    _tokensIn = Math.min(tokensToSell, tokensSold);
  }
}
