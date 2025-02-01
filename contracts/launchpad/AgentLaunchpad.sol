// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝    ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AgentToken} from "../token/AgentToken.sol";
import {IAgentToken} from "../interfaces/IAgentToken.sol";
import {IAeroPoolFactory} from "../interfaces/IAeroPoolFactory.sol";
import {AgentLaunchpadSale} from "./AgentLaunchpadSale.sol";

contract AgentLaunchpad is AgentLaunchpadSale {
    function initialize(address _fundingToken, address _aeroFactory, address _owner) external initializer {
        fundingToken = IERC20(_fundingToken);
        aeroFactory = IAeroPoolFactory(_aeroFactory);
        __Ownable_init(_owner);
    }

    function setSettings(
        uint256 _creationFee,
        uint256 _maxDuration,
        uint256 _minDuration,
        uint256 _minFundingGoal,
        address _governor,
        address _checker,
        address _feeDestination,
        uint256 _feeCutE18
    ) external onlyOwner {
        creationFee = _creationFee;
        maxDuration = _maxDuration;
        minDuration = _minDuration;
        minFundingGoal = _minFundingGoal;
        governor = _governor;
        checker = _checker;
        feeDestination = _feeDestination;
        feeCutE18 = _feeCutE18;

        emit SettingsUpdated(
            _creationFee, _maxDuration, _minDuration, _minFundingGoal, _governor, _checker, _feeDestination, _feeCutE18
        );
    }

    function whitelist(address _address, bool _what) external onlyOwner {
        whitelisted[_address] = _what;
    }

    function create(CreateParams memory p) external {
        require(p.duration >= minDuration, "!duration");
        require(p.duration <= maxDuration, "!duration");
        require(p.goal >= minFundingGoal, "!minFundingGoal");
        require(whitelisted[p.bondingCurve], "!bondingCurve");

        if (creationFee > 0) fundingToken.transferFrom(msg.sender, address(0xdead), creationFee);

        IAgentToken.InitParams memory params = IAgentToken.InitParams({
            name: p.name,
            symbol: p.symbol,
            metadata: p.metadata,
            fundManagers: p.fundManagers,
            limitPerWallet: p.limitPerWallet,
            governance: governor,
            txChecker: checker,
            expiry: block.timestamp + p.duration
        });

        AgentToken _token = new AgentToken{salt: p.salt}(params);

        emit TokenCreated(
            address(_token),
            msg.sender,
            p.name,
            p.symbol,
            p.limitPerWallet,
            p.goal,
            p.duration,
            p.metadata,
            p.bondingCurve,
            p.salt
        );
        tokens.push(_token);
    }

    function getTotalTokens() external view returns (uint256) {
        return tokens.length;
    }
}
