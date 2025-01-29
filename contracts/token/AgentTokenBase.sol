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
import {ICLFactory} from "../interfaces/ICLFactory.sol";
import {ILocker} from "../interfaces/ILocker.sol";

interface ITxChecker {
    function checkTransaction(address _to, uint256 _value, bytes memory _data, address _caller)
        external
        returns (bool);
}

abstract contract AgentTokenBase is ERC20Burnable, ERC20Permit, AccessControlEnumerable {
    // basic info
    string public metadata;
    bool public unlocked;
    ILocker public locker;
    ICLFactory public aeroFactory;

    // sale info
    IERC20 public fundingToken;
    uint256 public fundingGoal;

    // roles
    bytes32 public FUND_MANAGER = keccak256("FUND_MANAGER");
    bytes32 public GOVERNANCE = keccak256("GOVERNANCE");

    // treasury variables
    uint256 public expiry;
    address[] public assets;
    mapping(address => bool) public approvedAssets;

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
