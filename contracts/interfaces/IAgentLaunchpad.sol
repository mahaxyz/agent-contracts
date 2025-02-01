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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAgentToken} from "./IAgentToken.sol";
import {IAeroPool} from "./IAeroPool.sol";

interface IAgentLaunchpad {
    event TokenCreated(
        address indexed token,
        address indexed creator,
        string name,
        string symbol,
        uint256 limitPerWallet,
        uint256 goal,
        uint256 duration,
        string metadata,
        address bondingCurve,
        bytes32 salt
    );

    struct CreateParams {
        string name;
        string symbol;
        uint256 duration;
        uint256 limitPerWallet;
        uint256 goal;
        string metadata;
        address locker;
        address txChecker;
        address bondingCurve;
        bytes32 salt;
    }

    struct TokenLock {
        uint256 amount;
        uint256 startTime;
        uint256 duration;
    }

    struct LiquidityLock {
        IAeroPool liquidityToken;
        uint256 amount;
        uint256 releaseTime;
    }

    event TokensPurchased(IAgentToken indexed token, address indexed buyer, uint256 amountToken, uint256 amountETH);
    event TokensSold(IAgentToken indexed token, address indexed seller, uint256 amountToken, uint256 amountETH);
    event SettingsUpdated(
        uint256 creationFee,
        uint256 maxDuration,
        uint256 minDuration,
        uint256 minFundingGoal,
        address governor,
        address checker,
        address feeDestination,
        uint256 feeCutE18
    );

    function initialize(IERC20 _raiseToken, address _owner) external;

    function setSettings(
        uint256 _creationFee,
        uint256 _minFundingGoal,
        uint256 _minDuration,
        uint256 _maxDuration,
        address _locker,
        address _checker,
        address _governor
    ) external;

    function whitelist(address _address, bool _what) external;

    function create(CreateParams memory p) external;

    function getTotalTokens() external view returns (uint256);

    function releaseTokens() external;

    function releaseNFT() external;
}
