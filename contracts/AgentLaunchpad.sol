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

    function initialize(
        IERC20 _raiseToken,
        uint256 _creationFee,
        uint256 _minFundingGoal,
        uint256 _minDuration,
        uint256 _maxDuration,
        address _locker,
        address _governor,
        address _owner
    ) external initializer {
        raiseToken = _raiseToken;
        creationFee = _creationFee;
        minFundingGoal = _minFundingGoal;
        minDuration = _minDuration;
        maxDuration = _maxDuration;
        locker = _locker;
        governor = _governor;
        __Ownable_init(_owner);
    }

    function setSettings(
        uint256 _creationFee,
        uint256 _minFundingGoal,
        uint256 _minDuration,
        uint256 _maxDuration,
        address _locker,
        address _governor
    ) external onlyOwner {
        creationFee = _creationFee;
        minFundingGoal = _minFundingGoal;
        minDuration = _minDuration;
        maxDuration = _maxDuration;
        locker = _locker;
        governor = _governor;
    }

    function whitelist(address _address, bool _what) external onlyOwner {
        whitelisted[_address] = _what;
    }

    function create(CreateParams memory p) external {
        require(p.duration >= minDuration, "!duration");
        require(p.duration <= maxDuration, "!duration");
        require(p.goal >= minFundingGoal, "!minFundingGoal");
        require(whitelisted[p.bondingCurve], "!bondingCurve");
        require(whitelisted[p.txChecker], "!txChecker");
        require(whitelisted[p.locker], "!locker");

        address[] memory fundManagers = new address[](0);

        if (creationFee > 0) raiseToken.transferFrom(msg.sender, address(0xdead), creationFee);

        AgentToken _token = new AgentToken{salt: p.salt}(
            p.name,
            p.symbol,
            p.metadata,
            fundManagers,
            p.limitPerWallet,
            p.goal,
            address(raiseToken),
            governor,
            locker,
            address(p.bondingCurve),
            address(p.txChecker),
            block.timestamp + p.duration
        );

        emit TokenCreated(
            address(_token), msg.sender, p.name, p.symbol, p.goal, p.duration, p.metadata, p.bondingCurve, p.salt
        );
        tokens.push(_token);
    }

    function getTotalTokens() external view returns (uint256) {
        return tokens.length;
    }
}
