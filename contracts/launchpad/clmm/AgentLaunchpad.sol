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

contract AgentLaunchpad is AgentLaunchpadLocker {
  function initialize(address _coreToken, address _adapter, address _tokenImplementation, address _owner)
    external
    initializer
  {
    coreToken = IERC20(_coreToken);
    adapter = ICLMMAdapter(_adapter);
    tokenImplementation = _tokenImplementation;
    __Ownable_init(_owner);
    __ERC721_init("WAGMIE Launchpad", "WAGMIE");
  }

  function setSettings(uint256 _creationFee, address _feeDestination, uint256 _feeCutE18) external onlyOwner {
    creationFee = _creationFee;
  }

  function whitelist(address _address, bool _what) external onlyOwner {
    whitelisted[_address] = _what;
    // todo add event
  }

  function create(CreateParams memory p) external returns (address) {
    if (creationFee > 0) {
      p.base.fundingToken.transferFrom(msg.sender, address(0xdead), creationFee);
    }

    address[] memory whitelisted = new address[](2);
    whitelisted[0] = address(adapter.LAUNCHPAD());
    whitelisted[1] = address(this);

    IAgentToken.InitParams memory params = IAgentToken.InitParams({
      name: p.base.name,
      symbol: p.base.symbol,
      metadata: p.base.metadata,
      whitelisted: whitelisted,
      limitPerWallet: p.base.limitPerWallet,
      adapter: address(adapter)
    });

    IAgentToken token = IAgentToken(Clones.cloneDeterministic(tokenImplementation, p.base.salt));

    token.initialize(params);
    tokens.push(token);
    tokenToNftId[token] = tokens.length;
    launchParams[token] = p;

    token.approve(address(adapter), type(uint256).max);

    adapter.addSingleSidedLiquidity(
      token, // IERC20 _tokenBase,
      p.base.fundingToken, // IERC20 _tokenQuote,
      p.liquidity.amountBaseBeforeTick, // uint256 _amountBaseBeforeTick,
      p.liquidity.amountBaseAfterTick, // uint256 _amountBaseAfterTick,
      p.base.fee, // uint24 _fee,
      p.liquidity.lowerTick, // int24 _tick0,
      p.liquidity.upperTick, // int24 _tick1,
      p.liquidity.upperMaxTick // int24 _tick2
    );
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
