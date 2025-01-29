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

contract LinearCurve {
    uint256 public constant slope = 1; // Slope of the linear curve
    uint256 public constant intercept = 0; // Intercept of the linear curve

    function calculateBuy(uint256 quantityIn, uint256, uint256)
        public
        pure
        returns (uint256 _amountOut, uint256 _amountIn)
    {
        return (0, slope * quantityIn + intercept);
    }

    function calculateSell(uint256 quantityOut, uint256, uint256)
        public
        pure
        returns (uint256 _amountOut, uint256 _amountIn)
    {
        return (0, slope * quantityOut + intercept);
    }
}
