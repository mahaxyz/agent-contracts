// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Twitter: https://twitter.com/mahaxyz

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAgentToken {
    struct InitParams {
        string name;
        string symbol;
        string metadata;
        address[] fundManagers;
        uint256 limitPerWallet;
        uint256 fundingGoal;
        address fundingToken;
        address governance;
        address locker;
        address bondingCurve;
        address txChecker;
        uint256 expiry;
    }

    event TokensPurchased(address indexed buyer, uint256 amountToken, uint256 amountETH);
    event TokensSold(address indexed seller, uint256 amountToken, uint256 amountETH);

    event TransactionVetoed(bytes32 indexed txHash, address indexed by);
    event TransactionScheduled(bytes32 indexed txHash, address indexed to, uint256 value, bytes data, uint256 delay);
    event TransactionExecuted(bytes32 indexed txHash, address caller, address to, uint256 value, bytes data);
}
