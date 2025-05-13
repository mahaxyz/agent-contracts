// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IAirdropRewarder
 * @notice Interface for the AirdropRewarder contract that handles token airdrops using Merkle proofs
 */
interface IAirdropRewarder {
    struct TokenRewardInfo {
        bytes32 merkleRoot;
        bool isMerkleRootSet;
        bool isPremium;
        uint256 customRewardValue;
    }

    // Vesting info structure
  struct VestingInfo {
    uint256 startTime;          // When vesting began
    uint256 totalAmount;        // Total amount to vest
    uint256 upfrontAmount;      // Amount released upfront (25%)
    uint256 vestedAmount;       // Amount already released during vesting
  }
  
  
  // Events
  event TokenVestingStarted(address indexed token, address indexed account, uint256 total, uint256 upfront);
  event TokenVestingClaimed(address indexed token, address indexed account, uint256 amount);
  event AirdropRewarderSet(address indexed rewarder);
  event TokenAddedAsPremium(address indexed token, uint256 rewardValue);
  event TokenAddedAsRegular(address indexed token);

    // Events
    event MerkleRootSet(address indexed token, bytes32 merkleRoot);
    event RewardTokenAdded(address indexed token, bool isPremium, uint256 rewardValue);
    event RewardsClaimed(address indexed token, uint256 indexed index, address indexed account, uint256 amount);
    event RewardTerminated(address indexed token);
    event LaunchpadUpdated(address indexed newLaunchpad);

    // Errors
    error InvalidAddress();
    error MerkleRootAlreadySet();
    error InvalidRewardValue();
    error AlreadyClaimed();
    error InvalidMerkleProof();
    error MerkleRootNotSet();
    error InsufficientTokenBalance();
    error InvalidClaimer();
    error InvalidRoot();
    error OnlyServerCanSetMerkleRoot();
    /**
     * @notice Initialize the contract
     * @param _launchpad Address of the launchpad contract
     * @param _server Address of the server contract
     * @param _defaultRewardValue Default reward value for non-premium tokens
     */
    function initialize(address _launchpad, address _server, uint256 _defaultRewardValue) external;

    /**
     * @notice Set the Merkle root for a token
     * @param _token Address of the token
     * @param _merkleRoot Merkle root for the token's airdrop
     */
    function setMerkleRoot(address _token, bytes32 _merkleRoot) external;

    /**
     * @notice Set the launchpad address
     * @param _launchpad New launchpad address
     */
    function setLaunchpad(address _launchpad) external;

    /**
     * @notice Set the default reward value
     * @param _defaultRewardValue New default reward value
     */
    function setDefaultRewardValue(uint256 _defaultRewardValue) external;

    /**
     * @notice Claim airdropped tokens
     * @param _token Address of the token to claim
     * @param _index Unique index of the claim
     * @param _account Address that should receive the tokens
     * @param _amount Amount of tokens to claim
     * @param _merkleProofs Merkle proof array
     */
    function claim(
        address _token,
        uint256 _index,
        address _account,
        uint256 _amount,
        bytes32[] calldata _merkleProofs
    ) external;

    /**
     * @notice Withdraw all tokens of a specific type (admin only)
     * @param _token Address of the token to withdraw
     */
    function adminWithdrawal(address _token) external;

    /**
     * @notice Rescue accidentally sent tokens (admin only)
     * @param token Token to rescue
     * @param to Recipient address
     * @param amount Amount to rescue
     */
    function sweepTokens(address token, address to, uint256 amount) external;

    // View functions
    function defaultRewardValue() external view returns (uint256);
    function claimed(address, uint256) external view returns (bool);
    function launchpadAddress() external view returns (address);
} 