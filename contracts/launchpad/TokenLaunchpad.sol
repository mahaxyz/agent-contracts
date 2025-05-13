// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝    ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from
  "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH9} from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";

import {WAGMIEToken} from "contracts/WAGMIEToken.sol";
import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";
import {IAirdropRewarder} from "contracts/interfaces/IAirdropRewarder.sol";

import {ILaunchpool} from "contracts/interfaces/ILaunchpool.sol";
import {IReferralDistributor} from "contracts/interfaces/IReferralDistributor.sol";
import {ITokenLaunchpad} from "contracts/interfaces/ITokenLaunchpad.sol";

abstract contract TokenLaunchpad is ITokenLaunchpad, OwnableUpgradeable, ERC721EnumerableUpgradeable {
  using SafeERC20 for IERC20;

  address public feeDestination;
  ICLMMAdapter public adapter;
  IERC20 public premiumToken;
  IERC20[] public tokens;
  IReferralDistributor public referralDestination;
  IWETH9 public weth;
  uint256 public creationFee;
  uint256 public feeDiscountAmount;
  uint256 public referralFee;
  address public cron;

  mapping(IERC20 => CreateParams) public launchParams;
  mapping(IERC20 => uint256) public tokenToNftId;
  mapping(address => bool) public whitelisted;

  mapping(IERC20 => mapping(ICLMMAdapter => ValueParams)) public defaultValueParams;

  // Maximum allowed creator allocation percentage (5%)
  uint16 public constant MAX_CREATOR_ALLOCATION = 500;

  // Mapping to track adapter addresses by type
  mapping(ICLMMAdapter => bool) public adapters;

  // Airdrop Rewarder contract
  IAirdropRewarder public airdropRewarder;

  
  

  receive() external payable {}

  /// @inheritdoc ITokenLaunchpad
  function initialize(address _owner, address _weth, address _premiumToken) external initializer {
    weth = IWETH9(_weth);
    premiumToken = IERC20(_premiumToken);
    cron = _owner;
    __Ownable_init(_owner);
    __ERC721_init("WAGMIE Launchpad", "WAGMIE");
  }

  /// @inheritdoc ITokenLaunchpad
  function getTokenFee(IERC20 _token) external view returns (uint24 fee) {
    return launchParams[_token].valueParams.fee;
  }

  /// @inheritdoc ITokenLaunchpad
  function getQuoteToken(IERC20 _token) external view returns (IERC20 quoteToken) {
    return launchParams[_token].fundingToken;
  }

  /// @inheritdoc ITokenLaunchpad
  function setFeeSettings(address _feeDestination, uint256 _fee, uint256 _feeDiscountAmount) external onlyOwner {
    feeDestination = _feeDestination;
    creationFee = _fee;
    feeDiscountAmount = _feeDiscountAmount;
    emit FeeUpdated(_feeDestination, _fee);
  }

  /// @inheritdoc ITokenLaunchpad
  function setCron(address _cron) external onlyOwner {
    cron = _cron;
    emit CronUpdated(_cron);
  }

  /// @inheritdoc ITokenLaunchpad
  function toggleWhitelist(address _address) external onlyOwner {
    whitelisted[_address] = !whitelisted[_address];
    emit WhitelistUpdated(_address, whitelisted[_address]);
  }

  /// @inheritdoc ITokenLaunchpad
  function setReferralSettings(address _referralDestination, uint256 _referralFee) external onlyOwner {
    referralDestination = IReferralDistributor(_referralDestination);
    referralFee = _referralFee;
    emit ReferralUpdated(_referralDestination, _referralFee);
  }

  /// @inheritdoc ITokenLaunchpad
  function toggleAdapter(ICLMMAdapter _adapter) external onlyOwner {
    adapters[_adapter] = !adapters[_adapter];
    emit AdapterSet(address(_adapter), adapters[_adapter]);
  }

  /// @inheritdoc ITokenLaunchpad
  function setDefaultValueParams(IERC20 _token, ICLMMAdapter _adapter, ValueParams memory _params) external {
    require(msg.sender == cron, "!cron");
    defaultValueParams[_token][_adapter] = _params;
  }

  /// @inheritdoc ITokenLaunchpad
  function getDefaultValueParams(IERC20 _token, ICLMMAdapter _adapter) public view returns (ValueParams memory params) {
    require(adapters[_adapter]);
    params = defaultValueParams[_token][_adapter];
    require(params.fee > 0);
    return params;
  }

  /// @inheritdoc ITokenLaunchpad
  function getTokenAdapter(IERC20 _token) public view returns (ICLMMAdapter) {
    return launchParams[_token].adapter;
  }

  /// @inheritdoc ITokenLaunchpad
  function getTokenLaunchParams(IERC20 _token) public view returns (CreateParams memory params) {
    return launchParams[_token];
  }

  /// @inheritdoc ITokenLaunchpad
  function createAndBuy(CreateParams memory p, address expected, uint256 amount)
    external
    payable
    returns (address, uint256, uint256)
  {
    // Ensure creator allocation is within allowed limits
    require(p.creatorAllocation <= MAX_CREATOR_ALLOCATION, "Creator allocation exceeds maximum");

    // Get the appropriate adapter based on type
    require(adapters[p.adapter], "Adapter not set");

    // send any creation fee to the fee destination
    if (creationFee > 0) payable(feeDestination).transfer(creationFee);

    // wrap anything pending into weth
    if (address(this).balance > 0) weth.deposit{value: address(this).balance}();

    if (p.isPremium) {
      premiumToken.transferFrom(msg.sender, feeDestination, feeDiscountAmount);
    } else {
      // non-premium tokens can't have launchpool allocations
      require(p.launchPools.length == 0, "!premium-allocations");

      // Get default parameters for the funding token
      p.valueParams = getDefaultValueParams(p.fundingToken, p.adapter);
    }

    // take any pending balance from the sender
    if (amount > 0) {
      uint256 currentBalance = p.fundingToken.balanceOf(address(this));
      if (currentBalance < amount) p.fundingToken.transferFrom(msg.sender, address(this), amount - currentBalance);
    }

    WAGMIEToken token;

    {
      bytes32 salt = keccak256(abi.encode(p.salt, msg.sender, p.name, p.symbol));
      token = new WAGMIEToken{salt: salt}(p.name, p.symbol);
      require(expected == address(0) || address(token) == expected, "Invalid token address");

      tokenToNftId[token] = tokens.length;
      tokens.push(token);
      launchParams[token] = p;

      uint256 pendingBalance = token.balanceOf(address(this));
      token.approve(address(p.adapter), type(uint256).max);
      address pool = p.adapter.addSingleSidedLiquidity(
        ICLMMAdapter.AddLiquidityParams({
          tokenBase: token,
          tokenQuote: p.fundingToken,
          tick0: p.valueParams.launchTick,
          tick1: p.valueParams.graduationTick,
          tick2: p.valueParams.upperMaxTick,
          fee: p.valueParams.fee,
          tickSpacing: p.valueParams.tickSpacing,
          totalAmount: pendingBalance,
          graduationAmount: p.valueParams.graduationLiquidity
        })
      );
      emit TokenLaunched(token, address(p.adapter), pool, p);
    }

    _mint(msg.sender, tokenToNftId[token]);

    p.fundingToken.approve(address(p.adapter), type(uint256).max);

    // buy a small amount of tokens to register the token on tools like dexscreener
    uint256 balance = p.fundingToken.balanceOf(address(this));

    // buy 1 token
    uint256 swapped = p.adapter.swapWithExactOutput(p.fundingToken, token, 1 ether, balance, p.valueParams.fee);

    // if the user wants to buy more tokens, they can do so
    uint256 received;
    if (amount > 0) {
      received = p.adapter.swapWithExactInput(p.fundingToken, token, amount - swapped, 0, p.valueParams.fee);
    }

    // refund any remaining tokens
    _refundTokens(token);
    _refundTokens(p.fundingToken);
    _refundTokens(weth);

    return (address(token), received, swapped);
  }

  /// @inheritdoc ITokenLaunchpad
  function getTotalTokens() external view returns (uint256) {
    return tokens.length;
  }

  /// @inheritdoc ITokenLaunchpad
  function claimFees(IERC20 _token) external {
    address token1 = address(launchParams[_token].fundingToken);
    (uint256 fee0, uint256 fee1) = launchParams[_token].adapter.claimFees(address(_token));

    if (referralFee > 0) {
      uint256 referralFee0 = (fee0 * referralFee) / 100;
      uint256 referralFee1 = (fee1 * referralFee) / 100;

      _distributeReferralFees(address(_token), token1, referralFee0, referralFee1);
      _distributeFees(address(_token), ownerOf(tokenToNftId[_token]), token1, fee0 - referralFee0, fee1 - referralFee1);
    } else {
      _distributeFees(address(_token), ownerOf(tokenToNftId[_token]), token1, fee0, fee1);
    }
  }

  /// @dev Distribute fees to the owner
  /// @param _token0 The token to distribute fees from
  /// @param _owner The owner of the token
  /// @param _token1 The token to distribute fees to
  /// @param _amount0 The amount of fees to distribute from token0
  /// @param _amount1 The amount of fees to distribute from token1
  function _distributeFees(address _token0, address _owner, address _token1, uint256 _amount0, uint256 _amount1)
    internal
    virtual;

  /// @dev Distribute referral fees to the referral destination
  /// @param _token0 The token to distribute fees from
  /// @param _token1 The token to distribute fees to
  /// @param _amount0 The amount of fees to distribute from token0
  /// @param _amount1 The amount of fees to distribute from token1
  function _distributeReferralFees(address _token0, address _token1, uint256 _amount0, uint256 _amount1) internal {
    if (address(referralDestination) == address(0)) return;
    IERC20(_token0).approve(address(referralDestination), _amount0);
    IERC20(_token1).approve(address(referralDestination), _amount1);
    referralDestination.collectReferralFees(_token0, _token1, _amount0, _amount1);
  }

  /// @dev Refund tokens to the owner
  /// @param _token The token to refund
  function _refundTokens(IERC20 _token) internal {
    uint256 remaining = _token.balanceOf(address(this));
    if (remaining == 0) return;
    if (_token == weth) {
      weth.withdraw(remaining);
      payable(msg.sender).transfer(remaining);
    } else {
      _token.safeTransfer(msg.sender, remaining);
    }
  }

  /**
   * @notice Set the airdrop rewarder contract
   * @param _airdropRewarder Address of the airdrop rewarder
   */
  function setAirdropRewarder(address _airdropRewarder) external onlyOwner {
    require(_airdropRewarder != address(0), "Invalid address");
    airdropRewarder = IAirdropRewarder(_airdropRewarder);
    emit AirdropRewarderSet(_airdropRewarder);
  }
  
  /**
   * @notice Add a token as premium with custom reward value
   * @param _token Address of the token
   * @param _customRewardValue Custom reward value
   */
  function addPremiumToken(address _token, uint256 _customRewardValue) external onlyOwner {
    require(_token != address(0), "Invalid token address");
    require(_customRewardValue > 0, "Invalid reward value");
    
    airdropRewarder.addPremiumToken(_token, _customRewardValue);
    emit TokenAddedAsPremium(_token, _customRewardValue);
  }
  
  /**
   * @notice Add a token as regular
   * @param _token Address of the token
   */
  function addRegularToken(address _token) external onlyOwner {
    require(_token != address(0), "Invalid token address");
    
    airdropRewarder.addRegularToken(_token);
    emit TokenAddedAsRegular(_token);
  }
  
  
}
