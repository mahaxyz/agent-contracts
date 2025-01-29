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

import {ITxChecker, AgentTokenBase} from "./AgentTokenBase.sol";

abstract contract AgentTokenTimelock is AgentTokenBase {
    event TransactionVetoed(bytes32 indexed txHash, address indexed by);
    event TransactionScheduled(bytes32 indexed txHash, address indexed to, uint256 value, bytes data, uint256 delay);
    event TransactionExecuted(bytes32 indexed txHash, address caller, address to, uint256 value, bytes data);

    /// @notice Schedule a transaction to be executed after a delay
    /// @param _to The address to send the transaction to
    /// @param _value The amount of ETH to send with the transaction
    /// @param _data The data to send with the transaction
    /// @param _delay The delay in seconds before the transaction can be executed
    /// @dev Only fund managers and governance can schedule transactions
    function scheduleTx(address _to, uint256 _value, bytes memory _data, uint256 _delay) external payable {
        require(hasRole(FUND_MANAGER, msg.sender) || hasRole(GOVERNANCE, msg.sender), "!roles");
        require(block.timestamp < expiry, "!expiry");
        require(minDelay < _delay, "!expiry");

        // checker to avoid malicious txs
        if (txChecker != ITxChecker(address(0))) {
            require(txChecker.checkTransaction(_to, _value, _data, msg.sender));
        }

        Transaction memory t = Transaction({
            to: _to,
            value: _value,
            executeAt: block.timestamp + _delay,
            executed: false,
            cancelled: false,
            nonce: lastProposedNonce++,
            data: _data
        });

        bytes32 txHash = hashTx(t);
        transactions.push(t);
        hashToTransactions[txHash] = t;

        emit TransactionScheduled(txHash, _to, _value, _data, _delay);
    }

    /// @notice Execute a transaction that has been scheduled
    /// @param txHash The hash of the transaction to execute
    /// @dev Only transactions that have not been executed, are not cancelled, and have passed their executeAt time can be executed
    /// @dev Anyone can execute a scheduled transaction
    function executeTx(bytes32 txHash) external {
        Transaction storage t = hashToTransactions[txHash];
        require(t.executeAt < block.timestamp, "!executeAt");
        require(!t.cancelled, "!cancelled");
        require(!t.executed, "!executed");
        require(t.nonce >= lastExecutedNonce++, "!nonce"); // avoid old nonces from being executed
        t.executed = true;

        // checker to avoid malicious txs
        if (txChecker != ITxChecker(address(0))) {
            require(txChecker.checkTransaction(t.to, t.value, t.data, msg.sender));
        }

        (bool success,) = t.to.call{value: t.value}(t.data);
        require(success, "Transaction execution failed");
        emit TransactionExecuted(txHash, msg.sender, t.to, t.value, t.data);
    }

    /// @notice Veto a transaction that has been scheduled
    /// @param txHash The hash of the transaction to veto
    /// @dev Only transactions that have not been executed can be vetoed
    /// @dev Only governance can veto transactions
    function vetoTx(bytes32 txHash) external onlyRole(GOVERNANCE) {
        Transaction storage t = hashToTransactions[txHash];
        require(!t.executed, "!executed");
        t.cancelled = true;
        emit TransactionVetoed(txHash, msg.sender);
    }

    function hashTx(Transaction memory t) public pure returns (bytes32) {
        return keccak256(abi.encode(t.to, t.value, t.executeAt, t.data));
    }
}
