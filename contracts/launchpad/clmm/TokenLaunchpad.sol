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
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH9} from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";
import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";
import {IReferralDistributor} from "contracts/interfaces/IReferralDistributor.sol";
import {ITokenLaunchpad} from "contracts/interfaces/ITokenLaunchpad.sol";
import {ITokenTemplate} from "contracts/interfaces/ITokenTemplate.sol";

abstract contract TokenLaunchpad is ITokenLaunchpad, OwnableUpgradeable, ERC721EnumerableUpgradeable {
  using SafeERC20 for IERC20;

  address public feeDestination;
  address public tokenImplementation;
  ICLMMAdapter public adapter;
  IERC20[] public tokens;
  IReferralDistributor public referralDestination;
  IWETH9 public weth;
  uint256 public creationFee;
  uint256 public referralFee;
  address public ODOS;

  mapping(ITokenTemplate token => CreateParams) public launchParams;
  mapping(ITokenTemplate token => uint256) public tokenToNftId;

  receive() external payable {}

  /// @inheritdoc ITokenLaunchpad
  function initialize(address _adapter, address _tokenImplementation, address _owner, address _weth, address _odos)
    external
    initializer
  {
    adapter = ICLMMAdapter(_adapter);
    tokenImplementation = _tokenImplementation;
    weth = IWETH9(_weth);
    ODOS = _odos;
    __Ownable_init(_owner);
    __ERC721_init("WAGMIE Launchpad", "WAGMIE");
  }

  /// @inheritdoc ITokenLaunchpad
  function setFeeSettings(address _feeDestination, uint256 _fee) external onlyOwner {
    feeDestination = _feeDestination;
    creationFee = _fee;
    emit FeeUpdated(_feeDestination, _fee);
  }

  /// @inheritdoc ITokenLaunchpad
  function setReferralSettings(address _referralDestination, uint256 _referralFee) external onlyOwner {
    referralDestination = IReferralDistributor(_referralDestination);
    referralFee = _referralFee;
    emit ReferralUpdated(_referralDestination, _referralFee);
  }

  /// @inheritdoc ITokenLaunchpad
  function createAndBuy(CreateParams memory p, address expected, uint256 amount)
    external
    payable
    returns (address, uint256)
  {
    // send any creation fee to the fee destination
    if (creationFee > 0) payable(feeDestination).transfer(creationFee - msg.value);

    // wrap anything pending into weth
    if (address(this).balance > 0) weth.deposit{value: address(this).balance}();

    // take any pending balance from the sender
    if (amount > 0) {
      uint256 currentBalance = p.fundingToken.balanceOf(address(this));
      if (currentBalance < amount) p.fundingToken.transferFrom(msg.sender, address(this), amount - currentBalance);
    }

    ITokenTemplate token;

    {
      ITokenTemplate.InitParams memory params = ITokenTemplate.InitParams({
        name: p.name,
        symbol: p.symbol,
        metadata: p.metadata,
        limitPerWallet: p.limitPerWallet,
        adapter: address(adapter)
      });

      bytes32 salt = keccak256(abi.encode(p.salt, msg.sender, p.name, p.symbol));
      token = ITokenTemplate(Clones.cloneDeterministic(tokenImplementation, salt));
      require(expected == address(0) || address(token) == expected, "Invalid token address");
      token.initialize(params);
      tokenToNftId[token] = tokens.length;
      tokens.push(token);
      launchParams[token] = p;

      token.approve(address(adapter), type(uint256).max);
      adapter.addSingleSidedLiquidity(
        token, // IERC20 _tokenBase,
        p.fundingToken, // IERC20 _tokenQuote,
        p.launchTick, // int24 _tick0,
        p.graduationTick, // int24 _tick1,
        p.upperMaxTick // int24 _tick2
      );
      emit TokenLaunched(token, adapter.getPool(token), params);
    }
    {
      emit TokenLaunchParams(
        token,
        p.fundingToken,
        p.launchTick,
        p.graduationTick,
        p.upperMaxTick,
        p.limitPerWallet,
        p.name,
        p.symbol,
        p.metadata
      );
    }

    _mint(msg.sender, tokenToNftId[token]);

    p.fundingToken.approve(address(adapter), type(uint256).max);

    // buy a small amount of tokens to register the token on tools like dexscreener
    uint256 balance = p.fundingToken.balanceOf(address(this));
    uint256 swapped = adapter.swapWithExactOutput(p.fundingToken, token, 1 ether, balance); // buy 1 token

    // if the user wants to buy more tokens, they can do so
    uint256 received;
    if (amount > 0 && amount > swapped) received = adapter.swapForExactInput(p.fundingToken, token, amount - swapped, 0);

    // refund any remaining tokens
    _refundTokens(token);
    _refundTokens(p.fundingToken);
    _refundTokens(weth);

    return (address(token), received);
  }

  /// @inheritdoc ITokenLaunchpad
  function getTotalTokens() external view returns (uint256) {
    return tokens.length;
  }

  /// @inheritdoc ITokenLaunchpad
  function claimFees(ITokenTemplate _token) external {
    address token1 = address(launchParams[_token].fundingToken);
    (uint256 fee0, uint256 fee1) = adapter.claimFees(address(_token));

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
    IReferralDistributor distributor = referralDestination;
    distributor.collectReferralFees(_token0, _token1, _amount0, _amount1);
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

  /// @inheritdoc ITokenLaunchpad
  function buyWithExactInputWithOdos(
    IERC20 _odosTokenIn,
    IERC20 _tokenIn,
    IERC20 _tokenOut,
    uint256 _odosTokenInAmount,
    uint256 _minOdosTokenOut,
    uint256 _minAmountOut,
    bytes memory _odosData
  ) public payable returns (uint256 amountOut) {
    if (msg.value > 0) weth.deposit{value: msg.value}();
    else _odosTokenIn.safeTransferFrom(msg.sender, address(this), _odosTokenInAmount);
    _odosTokenIn.approve(address(adapter), type(uint256).max);

    // call the odos contract to get the amount of tokens to buy
    if (_odosData.length > 0) {
      (bool success,) = ODOS.call(_odosData);
      require(success, "!odos");
    } else {
      require(_odosTokenIn == _tokenOut, "!odosTokenIn");
    }

    // ensure that the odos has given us enough tokens to perform the raw swap
    uint256 amountIn = _tokenIn.balanceOf(address(this));
    require(amountIn >= _minOdosTokenOut, "!minAmountIn");

    amountOut = adapter.swapWithExactInput(_tokenIn, _tokenOut, amountIn, _minAmountOut);

    // send everything back
    _refundTokens(_tokenIn);
    _refundTokens(_tokenOut);
    _refundTokens(_odosTokenIn);
  }

  /// @inheritdoc ITokenLaunchpad
  function sellWithExactInputWithOdos(
    IERC20 _tokenIn,
    IERC20 _odosTokenOut,
    IERC20 _tokenOut,
    uint256 _tokenInAmount,
    uint256 _minOdosTokenIn,
    uint256 _minAmountOut,
    bytes memory _odosData
  ) public payable returns (uint256 amountOut) {
    _tokenIn.safeTransferFrom(msg.sender, address(this), _tokenInAmount);
    _tokenIn.approve(address(adapter), type(uint256).max);

    uint256 amountSwapOut = adapter.swapWithExactOutput(_tokenIn, _odosTokenOut, _tokenInAmount, _minOdosTokenIn);

    if (_odosData.length > 0) {
      _odosTokenOut.approve(ODOS, type(uint256).max);
      (bool success,) = ODOS.call(_odosData);
      require(success, "!odos");
      amountOut = _tokenOut.balanceOf(address(this));
    } else {
      require(_odosTokenOut == _tokenOut, "!odosTokenOut");
      amountOut = amountSwapOut;
    }

    require(amountOut >= _minAmountOut, "!minAmountOut");

    // send everything back
    _refundTokens(_tokenIn);
    _refundTokens(_tokenOut);
    _refundTokens(_odosTokenOut);
  }
}
