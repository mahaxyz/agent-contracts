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

import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ITxChecker} from "../interfaces/ITxChecker.sol";
import {IBondingCurve} from "../interfaces/IBondingCurve.sol";
import {ILocker} from "../interfaces/ILocker.sol";
import {IAgentToken} from "../interfaces/IAgentToken.sol";

abstract contract AgentTokenBase is IAgentToken, ERC20Burnable, ERC20Permit, AccessControlEnumerable {
    // basic info
    string public metadata;
    bool public unlocked;
    address public launchpad;
    uint256 public limitPerWallet;

    // roles
    bytes32 public FUND_MANAGER = keccak256("FUND_MANAGER");
    bytes32 public GOVERNANCE = keccak256("GOVERNANCE");

    // treasury variables
    uint256 public expiry;
    EnumerableSet.AddressSet internal assets;

    // timelock variables
    struct Transaction {
        address to;
        uint256 value;
        uint256 executeAt;
        uint256 nonce;
        bool executed;
        bool cancelled;
        bytes data;
    }

    ITxChecker public txChecker;
    uint256 lastProposedNonce;
    uint256 lastExecutedNonce;
    uint256 public minDelay;
    mapping(bytes32 => Transaction) public hashToTransactions;
    Transaction[] public transactions;

    receive() external payable {
        // accepts eth into this contract
    }
}
