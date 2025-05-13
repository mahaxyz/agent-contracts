// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IAirdropRewarder} from "../interfaces/IAirdropRewarder.sol";

/**
 * @title AirdropRewarder
 * @notice Distributes ERC20 tokens to users based on a Merkle root proof.
 *         Supports both regular and premium tokens with different reward values.
 *         Each token can have its Merkle root set only once by the launchpad.
 *         Uses index-based claim tracking to support multiple claims per address.
 */
contract AirdropRewarder is IAirdropRewarder, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public defaultRewardValue;
    mapping(address => bytes32) public tokenMerkleRoots;
    mapping(address => mapping(uint256 => bool)) public claimed;
    address public launchpadAddress;
    address public serverAddress;

    // Mapping of token to account to vesting info
    // Vesting duration in seconds (1 week)
  uint256 public constant VESTING_DURATION = 7 days;
  
  // Upfront percentage (25%)
  uint256 public constant UPFRONT_PERCENTAGE = 25;
  mapping(address => mapping(address => VestingInfo)) public vestingSchedules;
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _launchpad,
        address _server,
        uint256 _defaultRewardValue
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        
        if (_launchpad == address(0)) revert InvalidAddress();
        if (_defaultRewardValue == 0) revert InvalidRewardValue();
        launchpadAddress = _launchpad;
        serverAddress = _server;
        defaultRewardValue = _defaultRewardValue;
        
        emit LaunchpadUpdated(_launchpad);
    }

    modifier onlyServer() {
        if (msg.sender != serverAddress) revert OnlyServerCanSetMerkleRoot();
        _;
    }

    function setMerkleRoot(address _token, bytes32 _merkleRoot) external onlyServer{
        if (_token == address(0)) revert InvalidAddress();
        if (_merkleRoot == bytes32(0)) revert InvalidRoot();
        if (tokenMerkleRoots[_token] != bytes32(0)) revert MerkleRootAlreadySet();
        
        tokenMerkleRoots[_token] = _merkleRoot;
        
        emit MerkleRootSet(_token, _merkleRoot);
    }

    function startVesting(address _token, address _receiver, uint256 _amount) external onlyOwner {
    require(_token != address(0), "Invalid token address");
    require(_receiver != address(0), "Invalid receiver address");
    require(_amount > 0, "Invalid amount");
    
    // Get the token
    IERC20 token = IERC20(_token);
    
    // Calculate upfront amount (25%)
    uint256 upfrontAmount = (_amount * UPFRONT_PERCENTAGE) / 100;
    
    // Create vesting schedule
    vestingSchedules[_token][_receiver] = VestingInfo({
      startTime: block.timestamp,
      totalAmount: _amount,
      upfrontAmount: upfrontAmount,
      vestedAmount: 0
    });
    
    // Transfer upfront amount immediately
    token.transfer(_receiver, upfrontAmount);
    
    emit TokenVestingStarted(_token, _receiver, _amount, upfrontAmount);
  }
  
  /**
   * @notice Claim vested tokens
   * @param _token The token to claim
   */
  function claimVestedTokens(address _token) external {
    VestingInfo storage vestingInfo = vestingSchedules[_token][msg.sender];
    require(vestingInfo.totalAmount > 0, "No vesting found");
    
    // Calculate how much should be released at current time
    uint256 releasable = calculateReleasableAmount(_token, msg.sender);
    require(releasable > 0, "Nothing to claim");
    
    // Update vested amount
    vestingInfo.vestedAmount += releasable;
    
    // Transfer tokens
    IERC20(_token).transfer(msg.sender, releasable);
    
    emit TokenVestingClaimed(_token, msg.sender, releasable);
  }
  
  /**
   * @notice Calculate releasable amount based on vesting schedule
   * @param _token The token address
   * @param _account The account address
   * @return Amount that can be released
   */
  function calculateReleasableAmount(address _token, address _account) public view returns (uint256) {
    VestingInfo storage vestingInfo = vestingSchedules[_token][_account];
    
    // If nothing is vesting or vesting hasn't started yet
    if (vestingInfo.totalAmount == 0 || block.timestamp <= vestingInfo.startTime) {
      return 0;
    }
    
    // If vesting is complete
    if (block.timestamp >= vestingInfo.startTime + VESTING_DURATION) {
      return vestingInfo.totalAmount - vestingInfo.upfrontAmount - vestingInfo.vestedAmount;
    }
    
    // Calculate vested amount proportional to time passed (linear vesting)
    uint256 timeElapsed = block.timestamp - vestingInfo.startTime;
    uint256 remainingAmount = vestingInfo.totalAmount - vestingInfo.upfrontAmount;
    uint256 vestedAmount = (remainingAmount * timeElapsed) / VESTING_DURATION;
    
    // Return amount that can be claimed (subtract what's already been claimed)
    return vestedAmount - vestingInfo.vestedAmount;
  }

    function setLaunchpad(address _launchpad) external onlyOwner {
        if (_launchpad == address(0)) revert InvalidAddress();
        launchpadAddress = _launchpad;
        emit LaunchpadUpdated(_launchpad);
    }

    function setDefaultRewardValue(uint256 _defaultRewardValue) external onlyOwner {
        if (_defaultRewardValue == 0) revert InvalidRewardValue();
        defaultRewardValue = _defaultRewardValue;
    }

    function claim(
        address _token,
        uint256 _index,
        address _account,
        uint256 _amount,
        bytes32[] calldata _merkleProofs
    ) external nonReentrant {
        if (_account != msg.sender) revert InvalidClaimer();
        if (claimed[_token][_index]) revert AlreadyClaimed();
        
        if (tokenMerkleRoots[_token] == bytes32(0)) revert MerkleRootNotSet();
        
        bytes32 leaf = keccak256(abi.encodePacked(_index, _account, _amount));
        if (!MerkleProof.verify(_merkleProofs, tokenMerkleRoots[_token], leaf)) revert InvalidMerkleProof();
        
        claimed[_token][_index] = true;
        
        IERC20 token = IERC20(_token);
        if (token.balanceOf(address(this)) < _amount) revert InsufficientTokenBalance();
        
        token.safeTransfer(_account, _amount);
        
        emit RewardsClaimed(_token, _index, _account, _amount);
    }

    function adminWithdrawal(address _token) external onlyOwner {
        if (_token == address(0)) revert InvalidAddress();
        
        IERC20 token = IERC20(_token);
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
        emit RewardTerminated(_token);
    }

    function sweepTokens(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        if (to == address(0) || token == address(0)) revert InvalidAddress();
        IERC20(token).safeTransfer(to, amount);
    }

}