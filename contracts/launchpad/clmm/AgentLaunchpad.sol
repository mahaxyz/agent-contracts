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

import {AgentLaunchpadLocker} from "./AgentLaunchpadLocker.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAgentToken} from "contracts/interfaces/IAgentToken.sol";
import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";

abstract contract AgentLaunchpad is AgentLaunchpadLocker {
  function initialize(address _coreToken, address _adapter, address _tokenImplementation, address _owner)
    external
    initializer
  {
    coreToken = IERC20(_coreToken);
    adapter = ICLMMAdapter(_adapter);
    tokenImplementation = _tokenImplementation;
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
    // whitelisted[0] = address(adapter.LAUNCHPAD());
    whitelisted[1] = address(this);

    IAgentToken.InitParams memory params = IAgentToken.InitParams({
      name: p.name,
      symbol: p.symbol,
      metadata: p.metadata,
      whitelisted: whitelisted,
      limitPerWallet: p.limitPerWallet,
      adapter: address(adapter)
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

    adapter.addSingleSidedLiquidity(address(token), address(p.fundingToken), p.tokensToSell, p.goal, 0, 0, 0);
    _mint(msg.sender, tokenToNftId[token]);

    return address(token);
  }

  function getTotalTokens() external view returns (uint256) {
    return tokens.length;
  }

  function endsWithf406(address _addr) public pure returns (bool) {
    bytes20 addrBytes = bytes20(_addr);
    return (uint8(addrBytes[18]) == 0xf4 && uint8(addrBytes[19]) == 0x06);
  }
}
