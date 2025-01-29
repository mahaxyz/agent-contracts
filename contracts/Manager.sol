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

import {AgentLaunchpad} from "./AgentLaunchpad.sol";
import {ICLFactory} from "./interfaces/ICLFactory.sol";

contract Manager {
    ICLFactory public aeroFactory;

    AgentLaunchpad public agentLaunchpad;
    IERC20 public tradeToken;
    address public owner;
    uint256 public lockPeriod;
    uint256 public lastBurnTime;
    uint256 public burnInterval;

    event TokensLocked(address indexed user, uint256 amount, uint256 lockTime);
    event FeesBurned(uint256 amount, uint256 burnTime);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor(address _agentLaunchpad, address _tradeToken, uint256 _lockPeriod, uint256 _burnInterval) {
        agentLaunchpad = AgentLaunchpad(_agentLaunchpad);
        owner = msg.sender;
        lockPeriod = _lockPeriod;
        burnInterval = _burnInterval;
        tradeToken = IERC20(_tradeToken);
        lastBurnTime = block.timestamp;
    }

    function createLiquidityLock(IERC20 token, uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        token.transferFrom(msg.sender, address(this), amount);
        tradeToken.transferFrom(msg.sender, address(this), amount);
        // create LP on aerodrome
        emit TokensLocked(msg.sender, amount, block.timestamp);
    }

    // anyone can burn the fees of the token and create scarcity
    function burnFees(IERC20 token) external {
        // tradeToken
        // require(block.timestamp >= lastBurnTime + burnInterval, "Burn interval not reached");
        // uint256 fees = agentLaunchpad.collectFees();
        // agentLaunchpad.burn(fees);
        // lastBurnTime = block.timestamp;
        // emit FeesBurned(fees, lastBurnTime);
    }
}
