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

import {IBondingCurve} from "../interfaces/IBondingCurve.sol";

contract FixedCurve is IBondingCurve {
  //   uint256 tokensToBuyAfterFees;
  // uint256 fundingProgress;
  // uint256 fundingGoals;
  // uint256 tokensToSell;
  function calculateBuy(DataBuy memory data)
    public
    pure
    returns (uint256 _tokensOut, uint256 _assetsIn, uint256 _priceE18)
  {
    _priceE18 = data.fundingGoals * 1 ether / data.tokensToSell; // price in terms of 1 TOKEN = ? ASSET

    uint256 tokensSold = data.fundingProgress * 1 ether / _priceE18;
    uint256 remainingToSell = data.tokensToSell - tokensSold;

    _tokensOut = Math.min(data.tokensToBuyAfterFees, remainingToSell);
    _assetsIn = _tokensOut * _priceE18 / 1 ether;
  }

  function calculateSell(DataSell memory data)
    public
    pure
    returns (uint256 _assetsOut, uint256 _tokensIn, uint256 _priceE18)
  {
    // uint256 tokensToSell,
    // uint256 assetsRaised,
    // uint256 totalAssetRaise,
    // uint256 targetTokensToSell
    _priceE18 = data.totalRaise * 1 ether / data.targetTokensToSell; // price in terms of 1 TOKEN = ? ASSET
    uint256 tokensSold = data.raisedAmount * 1 ether / _priceE18;
    _assetsOut = data.quantityOut * _priceE18 / 1 ether;
    _tokensIn = Math.min(data.quantityOut, tokensSold);
  }
}
