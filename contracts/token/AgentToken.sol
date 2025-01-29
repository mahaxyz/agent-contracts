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
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _metadata,
        address[] memory _fundManagers,
        uint256 _limitPerWallet,
        uint256 _fundingGoal,
        address _fundingToken,
        address _governance,
        address _locker,
        address _bondingCurve,
        address _txChecker,
        uint256 _expiry
    ) ERC20(_name, _symbol) ERC20Permit(_symbol) {
        _mint(address(this), 1000000000 * 1e18); // 1 bn supply

        curve = IBondingCurve(_bondingCurve);
        expiry = _expiry;
        fundingGoal = _fundingGoal;
        fundingToken = IERC20(_fundingToken);
        limitPerWallet = _limitPerWallet;
        locker = ILocker(_locker);
        metadata = _metadata;
        txChecker = ITxChecker(_txChecker);
        unlocked = false;

        _grantRole(DEFAULT_ADMIN_ROLE, address(this)); // contract can only manage roles
        _grantRole(GOVERNANCE, _governance); // governance can schedule and veto txs

        // fund managers can schedule but not veto txs
        for (uint256 index = 0; index < _fundManagers.length; index++) {
            _grantRole(FUND_MANAGER, _fundManagers[index]);
        }
    }
}
