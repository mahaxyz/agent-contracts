// Helper function to round tick to the nearest tick spacing
export const roundTickToNearestTick = (tick: number, tickSpacing: number) => {
  return Math.round(tick / tickSpacing) * tickSpacing;
};

// Helper function to compute the tick price for a given market cap in USD
export const computeTickPrice = (
  marketCapInUSD: number,
  priceOfQuoteTokenInUSD: number,
  quoteSupplyDecimals: number,
  tickSpacing: number
) => {
  const e18 = 10n ** 18n;
  const marketCapInQuoteToken = marketCapInUSD / priceOfQuoteTokenInUSD;
  const totalSupply = 1000000000n * e18; // 1bn tokens
  const quoteSupply =
    (BigInt(Math.floor(marketCapInQuoteToken * 1000)) *
      10n ** BigInt(quoteSupplyDecimals)) /
    1000n;

  // Calculate sqrtPriceX96 following Uniswap v3 format
  const sqrtPriceRatio = (quoteSupply * e18) / totalSupply;

  const sqrtPriceX96 =
    BigInt(Math.floor(Math.sqrt(Number(sqrtPriceRatio)) * 2 ** 96)) /
    1000000000n;

  const tick = Math.floor(
    Math.log(Number(sqrtPriceX96) / 2 ** 96) / Math.log(Math.sqrt(1.0001))
  );

  return roundTickToNearestTick(tick, tickSpacing);
};
