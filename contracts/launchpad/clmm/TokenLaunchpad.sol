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
import {IWETH9} from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";
import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";
import {ITokenLaunchpad} from "contracts/interfaces/ITokenLaunchpad.sol";
import {ITokenTemplate} from "contracts/interfaces/ITokenTemplate.sol";

abstract contract TokenLaunchpad is ITokenLaunchpad, OwnableUpgradeable, ERC721EnumerableUpgradeable {
  address public tokenImplementation;
  IERC20[] public tokens;
  uint256 public creationFee;
  address public feeDestination;
  ICLMMAdapter public adapter;
  IWETH9 public weth;
  mapping(ITokenTemplate token => CreateParams) public launchParams;
  mapping(ITokenTemplate token => uint256) public tokenToNftId;

  receive() external payable {}

  /// @inheritdoc ITokenLaunchpad
  function initialize(address _adapter, address _tokenImplementation, address _owner, address _weth)
    external
    initializer
  {
    adapter = ICLMMAdapter(_adapter);
    tokenImplementation = _tokenImplementation;
    weth = IWETH9(_weth);
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
  function createAndBuy(CreateParams memory p, address expected, uint256 amount) external payable returns (address) {
    if (msg.value > 0) weth.deposit{value: msg.value}();

    if (creationFee > 0) {
      require(msg.value - amount >= creationFee, "!creationFee");
      weth.transfer(feeDestination, creationFee);
    }

    if (amount > 0) {
      uint256 currentBalance = p.fundingToken.balanceOf(address(this));
      if (currentBalance < amount) p.fundingToken.transferFrom(msg.sender, address(this), amount);
    }

    ITokenTemplate.InitParams memory params = ITokenTemplate.InitParams({
      name: p.name,
      symbol: p.symbol,
      metadata: p.metadata,
      limitPerWallet: p.limitPerWallet,
      adapter: address(adapter)
    });

    bytes32 salt = keccak256(abi.encode(p.salt, msg.sender, p.name, p.symbol));

    ITokenTemplate token = ITokenTemplate(Clones.cloneDeterministic(tokenImplementation, salt));
    require(expected == address(0) || address(token) == expected, "Invalid token address");

    token.initialize(params);
    tokens.push(token);
    tokenToNftId[token] = tokens.length;
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

    _mint(msg.sender, tokenToNftId[token]);

    p.fundingToken.approve(address(adapter), type(uint256).max);

    // buy a small amount of tokens to register the token on tools like dexscreener
    uint256 balance = p.fundingToken.balanceOf(address(this));
    uint256 swapped = adapter.swapForExactOutput(p.fundingToken, token, 1 ether, balance); // buy 1 token

    // if the user wants to buy more tokens, they can do so
    if (amount > 0) adapter.swapForExactInput(p.fundingToken, token, amount - swapped, 0);

    // refund any remaining tokens
    _refundTokens(token);
    _refundTokens(p.fundingToken);
    _refundTokens(weth);

    return address(token);
  }

  /// @inheritdoc ITokenLaunchpad
  function getTotalTokens() external view returns (uint256) {
    return tokens.length;
  }

  /// @inheritdoc ITokenLaunchpad
  function claimFees(ITokenTemplate _token) external {
    address token1 = address(launchParams[_token].fundingToken);
    (uint256 fee0, uint256 fee1) = adapter.claimFees(address(_token));
    _distributeFees(address(_token), ownerOf(tokenToNftId[_token]), token1, fee0, fee1);
  }

  function _distributeFees(address _token0, address _owner, address _token1, uint256 _amount0, uint256 _amount1)
    internal
    virtual;

  function _refundTokens(IERC20 _token) internal {
    uint256 remaining = _token.balanceOf(address(this));
    if (remaining == 0) return;
    if (_token == weth) {
      weth.withdraw(remaining);
      payable(msg.sender).transfer(remaining);
    } else {
      _token.transfer(msg.sender, remaining);
    }
  }
}
