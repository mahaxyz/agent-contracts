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

import "./AgentLaunchpad.sol";
import {ICLFactory} from "./interfaces/ICLFactory.sol";

contract TxChecker {
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

    function checkTransaction(address _to, uint256 _value, bytes memory _data, address _caller)
        external
        returns (bool)
    {
        return true;
    }
}
