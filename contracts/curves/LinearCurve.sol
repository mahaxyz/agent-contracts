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

    function calculateOut(uint256 quantityIn, uint256 target, uint256 totalRaised)
        public
        pure
        returns (uint256 amountOut, uint256 amountIn)
    {
        return (0, slope * quantityIn + intercept);
    }
}
