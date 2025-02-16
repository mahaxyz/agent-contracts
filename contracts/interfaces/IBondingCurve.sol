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

interface IBondingCurve {
  struct DataBuy {
    uint256 tokensToBuyAfterFees;
    uint256 fundingProgress;
    uint256 fundingGoals;
    uint256 tokensToSell;
  }

  struct DataSell {
    uint256 quantityOut;
    uint256 raisedAmount;
    uint256 totalRaise;
    uint256 targetTokensToSell;
  }

  function calculateBuy(DataBuy memory data)
    external
    view
    returns (uint256 _tokensOut, uint256 _assetsIn, uint256 _priceE18);

  function calculateSell(DataSell memory data)
    external
    view
    returns (uint256 _amountOut, uint256 _amountIn, uint256 _priceE18);
}
