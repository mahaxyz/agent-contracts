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

import {AgentTokenPresale} from "./AgentTokenPresale.sol";
import {IERC20, ERC20, ITxChecker, ILocker, IBondingCurve, ERC20Permit} from "./AgentTokenBase.sol";

contract AgentToken is AgentTokenPresale {
    constructor(InitParams memory p) ERC20(p.name, p.symbol) ERC20Permit(p.symbol) {
        launchpad = msg.sender;
        expiry = p.expiry;
        limitPerWallet = p.limitPerWallet;
        metadata = p.metadata;
        unlocked = false;

        _mint(msg.sender, 1000000000 * 1e18); // 1 bn supply
        _grantRole(DEFAULT_ADMIN_ROLE, address(this)); // contract can only manage roles
        _grantRole(GOVERNANCE, p.governance); // governance can schedule and veto txs

        // fund managers can schedule but not veto txs
        for (uint256 index = 0; index < p.fundManagers.length; index++) {
            _grantRole(FUND_MANAGER, p.fundManagers[index]);
        }
    }
}
