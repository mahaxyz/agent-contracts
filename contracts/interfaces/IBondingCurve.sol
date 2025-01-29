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
    function calculateOut(uint256 quantityIn, uint256 raisedAmount, uint256 totalRaise)
        external
        view
        returns (uint256 _amountOut, uint256 _amountIn);

    function calculateIn(uint256 quantityOut, uint256 raisedAmount, uint256 totalRaise)
        external
        view
        returns (uint256 _amountOut, uint256 _amountIn);
}
