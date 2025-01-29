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
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {AgentToken} from "./token/AgentToken.sol";
import {IAgentToken} from "./interfaces/IAgentToken.sol";
import {IAgentLaunchpad} from "./interfaces/IAgentLaunchpad.sol";

contract AgentLaunchpad is IAgentLaunchpad, OwnableUpgradeable {
    IERC20 public raiseToken;
    IERC20[] public tokens;
    mapping(address => bool) public whitelisted;
    uint256 public creationFee;
    uint256 public maxDuration;
    uint256 public minDuration;
    uint256 public minFundingGoal;

    address public locker;
    address public governor;
    address public checker;

    function initialize(IERC20 _raiseToken, address _owner) external initializer {
        raiseToken = _raiseToken;
        __Ownable_init(_owner);
    }

    function setSettings(
        uint256 _creationFee,
        uint256 _minFundingGoal,
        uint256 _minDuration,
        uint256 _maxDuration,
        address _locker,
        address _checker,
        address _governor
    ) external onlyOwner {
        creationFee = _creationFee;
        minFundingGoal = _minFundingGoal;
        minDuration = _minDuration;
        maxDuration = _maxDuration;
        locker = _locker;
        governor = _governor;
        checker = _checker;
    }

    function whitelist(address _address, bool _what) external onlyOwner {
        whitelisted[_address] = _what;
    }

    function create(CreateParams memory p) external {
        require(p.duration >= minDuration, "!duration");
        require(p.duration <= maxDuration, "!duration");
        require(p.goal >= minFundingGoal, "!minFundingGoal");
        require(whitelisted[p.bondingCurve], "!bondingCurve");

        address[] memory fundManagers = new address[](0);

        if (creationFee > 0) raiseToken.transferFrom(msg.sender, address(0xdead), creationFee);

        IAgentToken.InitParams memory params = IAgentToken.InitParams({
            name: p.name,
            symbol: p.symbol,
            metadata: p.metadata,
            fundManagers: fundManagers,
            limitPerWallet: p.limitPerWallet,
            fundingGoal: p.goal,
            fundingToken: address(raiseToken),
            governance: governor,
            locker: locker,
            bondingCurve: p.bondingCurve,
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
