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

import {IPoolFactory} from "../aerodrome/interfaces/IPoolFactory.sol";
import {IAgentToken} from "../interfaces/IAgentToken.sol";
import {IBondingCurve} from "../interfaces/IBondingCurve.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {AgentLaunchpadSale} from "./AgentLaunchpadSale.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";

import {LPFeeLibrary} from "lib/v4-core/src/libraries/LPFeeLibrary.sol";
import {Currency, CurrencyLibrary} from "lib/v4-core/src/types/Currency.sol";

import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolIdLibrary, PoolKey} from "lib/v4-core/src/types/PoolKey.sol";

contract AgentLaunchpad is AgentLaunchpadSale {
  using PoolIdLibrary for PoolKey;
  using CurrencyLibrary for Currency;

  function initialize(
    address _coreToken,
    address _odos,
    address _aeroFactory,
    address _tokenImplementation,
    address _owner,
    address _hook,
    address _poolManager
  ) external initializer {
    coreToken = IERC20(_coreToken);
    odos = _odos;
    aeroFactory = IPoolFactory(_aeroFactory);
    tokenImplementation = _tokenImplementation;
    hook = IHooks(_hook);
    poolManager = IPoolManager(_poolManager);
    __Ownable_init(_owner);
    __ERC721_init("AI Token Launchpad", "BLONKS");
  }

  function setSettings(
    uint256 _creationFee,
    uint256 _maxDuration,
    uint256 _minDuration,
    uint256 _minFundingGoal,
    address _feeDestination,
    uint256 _feeCutE18
  ) external onlyOwner {
    creationFee = _creationFee;
    maxDuration = _maxDuration;
    minDuration = _minDuration;
    minFundingGoal = _minFundingGoal;

    feeDestination = _feeDestination;
    feeCutE18 = _feeCutE18;

    emit SettingsUpdated(_creationFee, _maxDuration, _minDuration, _minFundingGoal, _feeDestination, _feeCutE18);
  }

  function whitelist(address _address, bool _what) external onlyOwner {
    whitelisted[_address] = _what;
    // todo add event
  }

  function create(CreateParams memory p) external returns (address) {
    require(p.goal >= minFundingGoal, "!minFundingGoal");
    require(whitelisted[p.bondingCurve], "!bondingCurve");
    require(whitelisted[address(p.fundingToken)], "!bondingCurve");

    if (creationFee > 0) {
      p.fundingToken.transferFrom(msg.sender, address(0xdead), creationFee);
    }

    address[] memory whitelisted = new address[](2);
    whitelisted[0] = odos;
    whitelisted[1] = address(this);

    IAgentToken.InitParams memory params = IAgentToken.InitParams({
      name: p.name,
      symbol: p.symbol,
      metadata: p.metadata,
      whitelisted: whitelisted,
      limitPerWallet: p.limitPerWallet
    });

    IAgentToken token = IAgentToken(Clones.cloneDeterministic(tokenImplementation, p.salt));

    token.initialize(params);

    emit TokenCreated(
      address(token),
      msg.sender,
      p.name,
      p.symbol,
      p.limitPerWallet,
      p.goal,
      p.tokensToSell,
      p.metadata,
      p.bondingCurve,
      p.salt
    );
    tokens.push(token);
    fundingTokens[token] = p.fundingToken;
    fundingGoals[token] = p.goal;
    tokensToSell[token] = p.tokensToSell;

    // TODO: Create a Uniswap V4 Pool
    address tokenAddress = address(token);
    address fundingTokenAddress = address(p.fundingToken);

    (address currency0, address currency1) =
      tokenAddress < fundingTokenAddress ? (tokenAddress, fundingTokenAddress) : (fundingTokenAddress, tokenAddress);

    // creating Uniswap v4 pool
    PoolKey memory poolKey = PoolKey({
      currency0: Currency.wrap(currency0),
      currency1: Currency.wrap(currency1),
      fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
      tickSpacing: 1, // for tight price range
      hooks: hook
    });
    uint160 sqrtPriceX96 = 79_228_162_514_264_337_593_543_950_336;
    poolManager.initialize(poolKey, sqrtPriceX96);

    // check if the address starts with 0xda0
    // require(startsWithDA0(address(token)), "!startsWithDA0");

    tokenToNftId[token] = tokens.length;
    curves[token] = IBondingCurve(p.bondingCurve);
    _mint(msg.sender, tokenToNftId[token]);

    return address(token);
  }

  function getTotalTokens() external view returns (uint256) {
    return tokens.length;
  }

  function startsWithDA0(address _addr) public pure returns (bool) {
    bytes20 addrBytes = bytes20(_addr);
    return (uint8(addrBytes[0]) == 0xda && uint8(addrBytes[1]) == 0x0);
  }
}
